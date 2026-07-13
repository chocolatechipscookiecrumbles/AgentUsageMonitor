import AppKit
import Combine
import Foundation

@MainActor
final class QuotaMonitor: ObservableObject {
    @Published private(set) var record: QuotaRecord
    @Published private(set) var refreshState: RefreshState = .idle

    private let repository: QuotaRepository
    private let diagnostics: RefreshDiagnosticsStore
    private let settings: AppSettings
    private let notifier: QuotaNotifier?
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(
        repository: QuotaRepository = QuotaRepository(),
        diagnostics: RefreshDiagnosticsStore = RefreshDiagnosticsStore(),
        settings: AppSettings
    ) {
        self.repository = repository
        self.diagnostics = diagnostics
        self.settings = settings
        notifier = Bundle.main.bundleURL.pathExtension == "app" ? QuotaNotifier(settings: settings) : nil
        record = .withoutForecasts(.unavailable("Codex quota unavailable. Refresh after signing in to Codex."))
    }

    deinit {
        refreshTask?.cancel()
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        }
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh(reason: .launch)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh(reason: .scheduled) }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh(reason: .wake) }
        }
    }

    func refresh(reason: RefreshReason) {
        guard refreshTask == nil else { return }
        let startedAt = Date()
        refreshState = .refreshing(reason: reason)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let freshRecord = await repository.refresh()
            guard !Task.isCancelled else { return }
            record = freshRecord
            let completedAt = Date()
            diagnostics.append(Self.diagnostic(for: freshRecord.presentation, reason: reason, startedAt: startedAt, completedAt: completedAt))
            refreshState = freshRecord.presentation.confirmation == .unavailable ? .failed(at: completedAt) : .idle
            refreshTask = nil
            await notifier?.evaluate(freshRecord)
        }
    }

    func refreshNotificationAuthorization() async -> NotificationAuthorizationState {
        guard let notifier else {
            settings.updateNotificationAuthorization(.unavailable)
            return .unavailable
        }
        return await notifier.refreshAuthorizationState()
    }

    func setAlertsEnabled(_ enabled: Bool) async -> NotificationAuthorizationState {
        guard let notifier else {
            settings.updateNotificationAuthorization(.unavailable)
            return .unavailable
        }
        return await notifier.setAlertsEnabled(enabled)
    }

    private static func diagnostic(
        for presentation: QuotaPresentation,
        reason: RefreshReason,
        startedAt: Date,
        completedAt: Date
    ) -> RefreshDiagnostic {
        let outcome = RefreshOutcome(rawValue: presentation.confirmation.rawValue) ?? .unavailable
        return RefreshDiagnostic(
            startedAt: startedAt,
            completedAt: completedAt,
            reason: reason,
            outcome: outcome,
            failureKind: failureKind(for: presentation)
        )
    }

    private static func failureKind(for presentation: QuotaPresentation) -> String? {
        guard presentation.confirmation == .unavailable || presentation.confirmation == .unconfirmed else { return nil }
        let detail = presentation.detail?.lowercased() ?? ""
        if detail.contains("executable") || detail.contains("not found") { return "codex-not-found" }
        if detail.contains("auth") || detail.contains("sign in") || detail.contains("login") { return "not-authenticated" }
        if detail.contains("timed out") || detail.contains("timeout") { return "timeout" }
        if detail.contains("agree") || detail.contains("transient") { return "inconsistent-samples" }
        return "invalid-response"
    }
}
