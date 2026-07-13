import AppKit
import Combine
import Foundation

@MainActor
final class QuotaViewModel: ObservableObject {
    @Published private(set) var presentation = QuotaPresentation.unavailable("Codex quota unavailable. Refresh after signing in to Codex.")
    @Published private(set) var fiveHourForecast: QuotaForecast?
    @Published private(set) var weeklyForecast: QuotaForecast?
    @Published private(set) var isRefreshing = false
    @Published private(set) var alertsEnabled = false
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown

    let settings: AppSettings
    private let monitor: QuotaMonitor
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        let settings = AppSettings()
        self.settings = settings
        monitor = QuotaMonitor(settings: settings)
        alertsEnabled = settings.alertsEnabled
        monitor.$record.sink { [weak self] record in
            self?.presentation = record.presentation
            self?.fiveHourForecast = record.fiveHourForecast
            self?.weeklyForecast = record.weeklyForecast
        }.store(in: &subscriptions)
        monitor.$refreshState.sink { [weak self] state in
            if case .refreshing = state { self?.isRefreshing = true } else { self?.isRefreshing = false }
        }.store(in: &subscriptions)
        settings.$alertsEnabled.removeDuplicates().sink { [weak self] enabled in
            self?.alertsEnabled = enabled
        }.store(in: &subscriptions)
        settings.$notificationAuthorizationState.removeDuplicates().sink { [weak self] state in
            self?.notificationAuthorizationState = state
        }.store(in: &subscriptions)
    }

    var menuBarTitle: String {
        guard let remaining = [presentation.fiveHour?.remainingPercent, presentation.weekly?.remainingPercent].compactMap({ $0 }).min() else {
            return "Codex"
        }
        return "Codex \(remaining)%"
    }

    func start() {
        monitor.start()
        Task { [weak self] in
            guard let self else { return }
            _ = await monitor.refreshNotificationAuthorization()
        }
    }

    func refresh() {
        monitor.refresh(reason: .manual)
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
}
