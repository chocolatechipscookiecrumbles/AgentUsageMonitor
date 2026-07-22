import AppKit
import Combine
import Foundation

@MainActor
final class QuotaViewModel: ObservableObject {
    @Published private(set) var presentation = QuotaPresentation.unavailable("Codex quota unavailable. Refresh after signing in to Codex.")
    @Published private(set) var displayState: QuotaDisplayState
    @Published private(set) var fiveHourForecast: QuotaForecast?
    @Published private(set) var weeklyForecast: QuotaForecast?
    @Published private(set) var refreshState: RefreshState = .idle
    @Published private(set) var diagnosticSummary: RefreshDiagnosticSummary = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var alertsEnabled = false
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var effectiveRefreshInterval: TimeInterval?
    @Published private(set) var refreshScheduleReason: RefreshScheduleReason?
    @Published private(set) var connectionState: AgentConnectionState = .checking
    @Published private(set) var refreshTimingPresentation: MenuRefreshTimingPresentation

    let settings: AppSettings
    private let monitor: QuotaMonitor
    private let connectionController: CodexConnectionController
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        let settings = AppSettings()
        self.settings = settings
        let monitor = QuotaMonitor(settings: settings)
        self.monitor = monitor
        let connectionController = CodexConnectionController {
            monitor.refresh(reason: .authentication)
        }
        self.connectionController = connectionController
        displayState = monitor.displayState
        refreshTimingPresentation = MenuRefreshTimingPresentation(
            lastRefreshAt: monitor.displayState.lastAttemptAt,
            refreshState: .idle,
            nextRefreshAt: nil,
        )
        alertsEnabled = settings.alertsEnabled
        monitor.$displayState.sink { [weak self] state in
            self?.displayState = state
            let displayedRecord = state.displayedRecord
            self?.presentation = displayedRecord?.presentation
                ?? QuotaPresentation.unavailable("No confirmed Codex quota result is available yet.")
            self?.fiveHourForecast = displayedRecord?.fiveHourForecast
            self?.weeklyForecast = displayedRecord?.weeklyForecast
            self?.updateRefreshTimingPresentation()
        }.store(in: &subscriptions)
        monitor.$refreshState.sink { [weak self] state in
            self?.refreshState = state
            if case .refreshing = state { self?.isRefreshing = true } else { self?.isRefreshing = false }
            if case .failed = state { self?.connectionController.recheckConnection() }
            self?.updateRefreshTimingPresentation()
        }.store(in: &subscriptions)
        monitor.$diagnosticSummary.sink { [weak self] summary in
            self?.diagnosticSummary = summary
        }.store(in: &subscriptions)
        monitor.$nextRefreshAt.sink { [weak self] nextRefreshAt in
            self?.nextRefreshAt = nextRefreshAt
            self?.updateRefreshTimingPresentation()
        }.store(in: &subscriptions)
        monitor.$effectiveRefreshInterval.sink { [weak self] in self?.effectiveRefreshInterval = $0 }.store(in: &subscriptions)
        monitor.$refreshScheduleReason.sink { [weak self] in self?.refreshScheduleReason = $0 }.store(in: &subscriptions)
        settings.$alertsEnabled.removeDuplicates().sink { [weak self] enabled in
            self?.alertsEnabled = enabled
        }.store(in: &subscriptions)
        settings.$notificationAuthorizationState.removeDuplicates().sink { [weak self] state in
            self?.notificationAuthorizationState = state
        }.store(in: &subscriptions)
        connectionController.$state.removeDuplicates().sink { [weak self] state in
            self?.connectionState = state
        }.store(in: &subscriptions)
        if !CommandLine.arguments.contains("--live-read-once")
            && !CommandLine.arguments.contains(ClaudeUsageProbeCommand.flag) {
            start()
        }
    }

    var settingsStatus: SettingsStatus {
        SettingsStatus.make(
            displayState: displayState,
            refreshState: refreshState,
            diagnostics: diagnosticSummary
        )
    }

    func start() {
        connectionController.start()
        monitor.start()
        Task { [weak self] in
            guard let self else { return }
            _ = await monitor.refreshNotificationAuthorization()
        }
    }

    func refresh() {
        monitor.refresh(reason: .manual)
    }

    func checkCodexConnection() {
        connectionController.checkConnection()
    }

    func signInWithBrowser() {
        connectionController.signInWithBrowser()
    }

    func signInWithCLI() {
        connectionController.signInWithCLI()
    }

    func setAlertsEnabled(_ enabled: Bool) {
        Task { [weak self] in
            guard let self else { return }
            let state = await monitor.setAlertsEnabled(enabled)
            if enabled, state == .denied {
                openNotificationSettings()
            }
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateRefreshTimingPresentation() {
        let newPresentation = MenuRefreshTimingPresentation(
            lastRefreshAt: displayState.lastAttemptAt,
            refreshState: refreshState,
            nextRefreshAt: nextRefreshAt,
        )
        if newPresentation != refreshTimingPresentation {
            refreshTimingPresentation = newPresentation
        }
    }
}
