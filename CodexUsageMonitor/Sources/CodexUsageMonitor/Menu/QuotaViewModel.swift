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
    @Published private(set) var effectiveRefreshInterval: TimeInterval?
    @Published private(set) var refreshScheduleReason: RefreshScheduleReason?
    @Published private(set) var connectionState: AgentConnectionState = .checking
    /// Claude's read cycle, owned here the same way Codex's QuotaMonitor is.
    @Published private(set) var claudeState: ClaudeUsageState = .unavailable(reason: ClaudeUsageState.notConnectedReason)
    @Published private(set) var claudeConnectionState: ClaudeConnectionState = .notConnected
    /// Result of the last manual CLI probe, so the page can report a failure
    /// the user paid tokens for.
    @Published private(set) var claudeCLIProbeError: String?
    @Published private(set) var isRunningClaudeCLIProbe = false
    @Published private(set) var isRefreshingClaude = false
    @Published private(set) var claudeSetupState: ClaudeSetupState

    let settings: AppSettings
    private let monitor: QuotaMonitor
    private let claudeMonitor: ClaudeUsageMonitor
    private let claudeConnectionController: ClaudeConnectionController
    private let connectionController: CodexConnectionController
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        let settings = AppSettings(
            legacyClaudeSetupEvidence: AppSettings.hasLegacyClaudeSetupEvidence()
        )
        self.settings = settings
        claudeSetupState = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .unavailable(reason: ClaudeUsageState.notConnectedReason),
            hasSetupHistory: settings.hasClaudeSetupHistory,
            hasCompletedSourceDiscovery: false
        )
        let monitor = QuotaMonitor(settings: settings)
        self.monitor = monitor
        let connectionController = CodexConnectionController {
            monitor.refresh(reason: .authentication)
        }
        self.connectionController = connectionController
        let claudeMonitor = ClaudeUsageMonitor()
        self.claudeMonitor = claudeMonitor
        self.claudeConnectionController = ClaudeConnectionController(
            browserSignIn: {
                // Browser sign-in (claude setup-token) is shelved as unverified;
                // it must not be presented as working. See the spike findings.
                throw ClaudeSetupTokenError.missingCLI
            },
            credentialsSignIn: {
                // Proof of connection is a real usage read. User-initiated, so
                // this is the one path allowed to raise the Keychain prompt.
                let source = ClaudeOAuthUsageSource(credentialStore: ClaudeCompositeCredentialStore())
                let snapshot = try await source.fetch(
                    promptPolicy: ClaudeRefreshReason.userInitiated.keychainPromptPolicy
                )
                return ClaudeAccountSummary(planType: snapshot.planHint)
            }
        )
        displayState = monitor.displayState
        alertsEnabled = settings.alertsEnabled
        monitor.$displayState.sink { [weak self] state in
            self?.displayState = state
            let displayedRecord = state.displayedRecord
            self?.presentation = displayedRecord?.presentation
                ?? QuotaPresentation.unavailable("No confirmed Codex quota result is available yet.")
            self?.fiveHourForecast = displayedRecord?.fiveHourForecast
            self?.weeklyForecast = displayedRecord?.weeklyForecast
        }.store(in: &subscriptions)
        monitor.$refreshState.sink { [weak self] state in
            self?.refreshState = state
            if case .refreshing = state { self?.isRefreshing = true } else { self?.isRefreshing = false }
            if case .failed = state { self?.connectionController.recheckConnection() }
        }.store(in: &subscriptions)
        monitor.$diagnosticSummary.sink { [weak self] summary in
            self?.diagnosticSummary = summary
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
        claudeMonitor.$state.sink { [weak self] state in
            self?.claudeState = state
            self?.updateClaudeSetupState()
        }.store(in: &subscriptions)
        claudeMonitor.$hasCompletedInitialRefresh.removeDuplicates().sink { [weak self] _ in
            self?.updateClaudeSetupState()
        }.store(in: &subscriptions)
        claudeMonitor.$isRefreshing.removeDuplicates().sink { [weak self] isRefreshing in
            self?.isRefreshingClaude = isRefreshing
        }.store(in: &subscriptions)
        claudeConnectionController.$state.removeDuplicates().sink { [weak self] state in
            self?.claudeConnectionState = state
            self?.updateClaudeSetupState()
            // A successful connect proves the credential works; pull usage now
            // rather than waiting for the next scheduled refresh.
            if state.isConnected { self?.refreshClaude() }
        }.store(in: &subscriptions)
        if Self.shouldStartProviderMonitoring(arguments: CommandLine.arguments) {
            start()
        }
    }

    static func shouldStartProviderMonitoring(arguments: [String]) -> Bool {
        !arguments.contains("--live-read-once")
            && !arguments.contains(ClaudeUsageProbeCommand.flag)
            && !arguments.contains(MenuPopoverViabilityGate.launchArgument)
            && !arguments.contains(ProviderSwitchTrace.launchArgument)
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
        claudeMonitor.start()
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

    /// User-initiated: this is the only path allowed to raise a Keychain
    /// prompt, so it must never be called from a background trigger.
    func refreshClaude() {
        Task { [claudeMonitor] in
            await claudeMonitor.refreshNow(reason: .userInitiated)
        }
    }

    /// Explicit user action — the only path that may raise the Keychain
    /// prompt for Claude Code's credential.
    func connectClaudeWithCredentials() {
        claudeConnectionController.useClaudeCodeCredentials()
    }

    func disconnectClaude() {
        claudeConnectionController.signOut()
    }

    /// Tier 2. Manual only, and only after the user has consented to the
    /// token cost — never called from a scheduled refresh.
    func runClaudeCLIProbe() {
        guard !isRunningClaudeCLIProbe else { return }
        isRunningClaudeCLIProbe = true
        claudeCLIProbeError = nil
        Task { [weak self] in
            defer { Task { @MainActor [weak self] in self?.isRunningClaudeCLIProbe = false } }
            do {
                let snapshot = try await ClaudeCLIUsageProbe().run()
                await MainActor.run { [weak self] in
                    self?.claudeMonitor.applyManualSnapshot(snapshot)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.claudeCLIProbeError = Self.cliProbeMessage(for: error)
                }
            }
        }
    }

    private static func cliProbeMessage(for error: Error) -> String {
        switch error as? ClaudeCLIProbeError {
        case .missingCLI:
            "The Claude Code CLI could not be found. Install it, then try again."
        case .commandFailed:
            "The Claude Code CLI could not complete the check. Make sure you are signed in to it."
        case .couldNotParseOutput:
            "The CLI ran but its usage output could not be read. This build may need updating for a newer CLI."
        case nil:
            "The usage check could not be completed."
        }
    }

    private func updateClaudeSetupState() {
        if ClaudeSetupState.hasCurrentEvidence(
            connectionState: claudeConnectionState,
            usageState: claudeState
        ) {
            settings.recordClaudeSetupHistory()
        }
        claudeSetupState = ClaudeSetupState.resolve(
            connectionState: claudeConnectionState,
            usageState: claudeState,
            hasSetupHistory: settings.hasClaudeSetupHistory,
            hasCompletedSourceDiscovery: claudeMonitor.hasCompletedInitialRefresh
        )
    }

    func stopClaude() {
        claudeMonitor.stop()
    }
}
