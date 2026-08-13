import AppKit
import Combine
import Foundation

@MainActor
final class QuotaMonitor: ObservableObject {
    @Published private(set) var record: QuotaRecord
    @Published private(set) var displayState: QuotaDisplayState
    @Published private(set) var refreshState: RefreshState = .idle
    @Published private(set) var diagnosticSummary: RefreshDiagnosticSummary
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var effectiveRefreshInterval: TimeInterval?
    @Published private(set) var refreshScheduleReason: RefreshScheduleReason?
    @Published private(set) var interruptionState: RefreshInterruptionState

    private let repository: QuotaRepository
    private let diagnostics: RefreshDiagnosticsStore
    private let interruptionStore: RefreshInterruptionStore
    private let settings: AppSettings
    /// The consent gate. Codex quota work runs only while this reports
    /// `.enabled`; the monitor never infers permission from a CLI session.
    private let enrollment: ProviderEnrollmentStore
    private let notifier: QuotaNotifier?
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var settingsSubscription: AnyCancellable?
    private var disconnectSubscription: AnyCancellable?
    private var hasStarted = false
    private var hasPendingAuthenticationRefresh = false
    private var automaticBurstStartedAt: Date?

    init(
        repository: QuotaRepository = QuotaRepository(),
        diagnostics: RefreshDiagnosticsStore = RefreshDiagnosticsStore(),
        interruptionStore: RefreshInterruptionStore = RefreshInterruptionStore(),
        settings: AppSettings,
        enrollment: ProviderEnrollmentStore
    ) {
        self.repository = repository
        self.diagnostics = diagnostics
        self.interruptionStore = interruptionStore
        self.settings = settings
        self.enrollment = enrollment
        interruptionState = interruptionStore.load()
        notifier = Bundle.main.bundleURL.pathExtension == "app" ? QuotaNotifier(settings: settings) : nil
        let initialRecord = QuotaRecord.withoutForecasts(.unavailable("Codex quota unavailable. Refresh after signing in to Codex."))
        record = initialRecord
        displayState = QuotaDisplayState(
            mode: .cachedPaused,
            displayedRecord: nil,
            lastAttemptAt: initialRecord.presentation.collectedAt,
            lastConfirmedAt: nil,
            pauseReason: .unavailable
        )
        diagnosticSummary = diagnostics.diagnosticSummary(
            from: Date().addingTimeInterval(-30 * 24 * 3_600),
            through: .now
        )
    }

    deinit {
        refreshTask?.cancel()
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            settingsSubscription?.cancel()
            disconnectSubscription?.cancel()
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        settingsSubscription = settings.$refreshMode
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshModeChanged()
            }
        disconnectSubscription = enrollment.$states
            .map { ($0[.codex] ?? .notRequested) != .enabled }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] disconnected in
                guard let self else { return }
                if disconnected {
                    self.applyDisconnectedState()
                } else {
                    self.refresh(reason: .authentication)
                }
            }
        refresh(reason: .launch)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.settings.refreshOnWake else { return }
                self.refresh(reason: .wake)
            }
        }
    }

    /// Blanks Codex usage for an app-local disconnect: cancels any in-flight
    /// read, stops scheduling, and shows an explicit disconnected state without
    /// touching the CLI session.
    private func applyDisconnectedState() {
        refreshTask?.cancel()
        refreshTask = nil
        invalidateRefreshTimer()
        nextRefreshAt = nil
        let disconnected = QuotaRecord.withoutForecasts(
            .unavailable("Codex is disconnected. Reconnect to show usage.")
        )
        record = disconnected
        displayState = QuotaDisplayState(
            mode: .cachedPaused,
            displayedRecord: nil,
            lastAttemptAt: disconnected.presentation.collectedAt,
            lastConfirmedAt: nil,
            pauseReason: .unavailable
        )
        refreshState = .idle
    }

    /// Discards the recorded refresh history at the user's request. Only the
    /// diagnostics record is affected: quota state, cached readings, and the
    /// refresh schedule are untouched, and the next completed refresh starts a
    /// new history.
    func clearDiagnostics() {
        diagnostics.clear()
        diagnosticSummary = .empty
    }

    func refresh(reason: RefreshReason) {
        // No explicit enrollment means no read, whatever the trigger was:
        // launch, wake, schedule, manual, or an authentication transition.
        guard enrollment.isEnabled(.codex) else {
            applyDisconnectedState()
            return
        }
        guard refreshTask == nil else {
            if reason == .authentication {
                hasPendingAuthenticationRefresh = true
            }
            return
        }
        invalidateRefreshTimer()
        let startedAt = Date()
        refreshState = .refreshing(reason: reason)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let freshRecord = await repository.refresh()
            guard !Task.isCancelled else {
                refreshTask = nil
                return
            }
            record = freshRecord
            let completedAt = Date()
            let diagnostic = Self.diagnostic(
                for: freshRecord.presentation,
                reason: reason,
                startedAt: startedAt,
                completedAt: completedAt
            )
            let interruptionTransition = updateDisplayState(
                with: freshRecord,
                completedAt: completedAt,
                failureKind: diagnostic.failureKind
            )
            diagnostics.append(diagnostic)
            diagnosticSummary = diagnostics.diagnosticSummary(
                from: completedAt.addingTimeInterval(-30 * 24 * 3_600),
                through: completedAt
            )
            refreshState = freshRecord.presentation.confirmation == .confirmed || freshRecord.presentation.confirmation == .confirmedAfterRetry
                ? .idle
                : .failed(at: completedAt)
            await notifier?.evaluate(
                freshRecord,
                interruptionState: interruptionState,
                interruptionTransition: interruptionTransition
            )
            refreshTask = nil
            if hasPendingAuthenticationRefresh {
                hasPendingAuthenticationRefresh = false
                refresh(reason: .authentication)
            } else {
                scheduleNextRefresh(from: completedAt)
            }
        }
    }

    private func updateDisplayState(
        with freshRecord: QuotaRecord,
        completedAt: Date,
        failureKind: String?
    ) -> RefreshInterruptionTransition {
        let transition = updateInterruptionState(
            presentation: freshRecord.presentation,
            completedAt: completedAt,
            failureKind: failureKind
        )
        let failureCount = interruptionState.episode?.failureCount ?? 0
        switch freshRecord.presentation.confirmation {
        case .confirmed, .confirmedAfterRetry:
            displayState = QuotaDisplayState(
                mode: .confirmedCompleted,
                displayedRecord: freshRecord,
                lastAttemptAt: completedAt,
                lastConfirmedAt: freshRecord.presentation.collectedAt,
                pauseReason: nil
            )
        case .cachedLastKnownGood:
            displayState = QuotaDisplayState(
                mode: .cachedPaused,
                displayedRecord: displayState.displayedRecord ?? freshRecord,
                lastAttemptAt: completedAt,
                lastConfirmedAt: displayState.lastConfirmedAt ?? freshRecord.presentation.collectedAt,
                pauseReason: failureCount >= 2 ? .repeatedFailures : .cachedLastKnownGood
            )
        case .unconfirmed, .unavailable:
            displayState = QuotaDisplayState(
                mode: .cachedPaused,
                displayedRecord: displayState.displayedRecord,
                lastAttemptAt: completedAt,
                lastConfirmedAt: displayState.lastConfirmedAt,
                pauseReason: failureCount >= 2
                    ? .repeatedFailures
                    : (freshRecord.presentation.confirmation == .unconfirmed ? .unconfirmed : .unavailable)
            )
        }
        return transition
    }

    private func updateInterruptionState(
        presentation: QuotaPresentation,
        completedAt: Date,
        failureKind: String?
    ) -> RefreshInterruptionTransition {
        let confirmation = presentation.confirmation
        if confirmation == .confirmed || confirmation == .confirmedAfterRetry {
            guard let episode = interruptionState.episode else { return .none }
            interruptionState = .healthy
            interruptionStore.save(.healthy)
            return .recovered(episode)
        }

        if failureKind == "codex-not-found" || failureKind == "not-authenticated" {
            interruptionState = .healthy
            interruptionStore.save(.healthy)
            return .none
        }

        switch interruptionState {
        case .healthy:
            let episode = RefreshInterruptionEpisode.start(
                firstFailureAt: completedAt,
                lastConfirmedAt: displayState.lastConfirmedAt
                    ?? (confirmation == .cachedLastKnownGood ? presentation.collectedAt : nil)
            )
            interruptionState = .observing(episode)
            interruptionStore.save(interruptionState)
            return .none
        case .observing(var episode):
            episode.failureCount += 1
            if episode.failureCount >= 3 {
                interruptionState = .backedOff(episode)
                interruptionStore.save(interruptionState)
                return .alertEligible(episode)
            }
            interruptionState = .observing(episode)
            interruptionStore.save(interruptionState)
            return .none
        case .backedOff(var episode):
            episode.failureCount += 1
            interruptionState = .backedOff(episode)
            interruptionStore.save(interruptionState)
            return .none
        }
    }

    private func scheduleNextRefresh(from date: Date) {
        let decision = AdaptiveRefreshPolicy.decision(
            mode: settings.refreshMode,
            record: displayState.displayedRecord,
            interruptionState: interruptionState,
            burstStartedAt: automaticBurstStartedAt,
            now: date
        )
        if decision.isAutomaticBurst {
            automaticBurstStartedAt = automaticBurstStartedAt ?? date
        } else if !decision.isBurstConditionActive {
            automaticBurstStartedAt = nil
        }
        effectiveRefreshInterval = decision.interval
        refreshScheduleReason = decision.reason
        nextRefreshAt = date.addingTimeInterval(decision.interval)
        let timer = Timer(timeInterval: decision.interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTimer = nil
                self?.nextRefreshAt = nil
                self?.refresh(reason: .scheduled)
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshModeChanged() {
        automaticBurstStartedAt = nil
        invalidateRefreshTimer()
        guard refreshTask == nil else { return }
        scheduleNextRefresh(from: .now)
    }

    private func invalidateRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        nextRefreshAt = nil
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
