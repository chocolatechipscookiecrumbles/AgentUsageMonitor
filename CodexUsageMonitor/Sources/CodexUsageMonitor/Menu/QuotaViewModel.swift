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
    private var claudeCLIProbeGeneration = 0
    @Published private(set) var isRunningClaudeCLIProbe = false
    @Published private(set) var isRefreshingClaude = false
    @Published private(set) var claudeSetupState: ClaudeSetupState

    /// Local Token Activity observed on this Mac. It is deliberately separate
    /// from the quota pipeline: it starts with app monitoring, not with a
    /// connection, and it stays readable while a provider's quota is not.
    @Published private(set) var localActivityStates: [AgentProvider: ProviderLocalActivityState] = [:]

    let settings: AppSettings
    /// The one owner of app-local provider consent. Shared with the menu,
    /// Settings, and the quota owners so nothing has to guess whether the user
    /// asked for a provider.
    let enrollment: ProviderEnrollmentStore

    /// Providers currently connected enough to show a menu-bar reading, in
    /// canonical order. Drives the smart provider selector: with fewer than two,
    /// the effective provider is forced and no selector is offered.
    var menuBarEligibleProviders: [AgentProvider] {
        MenuBarProviderSelection.eligibleProviders(
            codexDisplayState: displayState,
            claudeState: claudeState
        )
    }

    /// The provider the single-provider menu-bar styles should render: the
    /// user's stored choice when it is connected, otherwise the sole connected
    /// provider.
    var effectiveMenuBarProvider: AgentProvider {
        MenuBarProviderSelection.effectiveProvider(
            stored: settings.menuBarProvider,
            eligible: menuBarEligibleProviders
        )
    }

    private let monitor: QuotaMonitor
    private let claudeMonitor: ClaudeUsageMonitor
    private let activityMonitor: LocalActivityMonitor
    /// App-level notifier for things `QuotaMonitor` (Codex) does not own: Claude
    /// threshold alerts and quota-setting confirmations. Shares the same
    /// authorization gate and UserDefaults dedup, so it cannot double-fire.
    private let appNotifier: QuotaNotifier?
    private let claudeConnectionController: ClaudeConnectionController
    private let claudeUsageCache: ClaudeUsageCache
    private let connectionController: CodexConnectionController
    private var subscriptions: Set<AnyCancellable> = []
    /// Confirmation debounce: newly-enabled thresholds are collected and one
    /// summary notification is sent 3 seconds after the last toggle.
    private var previousThresholds: [AgentProvider: Set<RemainingQuotaThreshold>]
    private var pendingConfirmations: Set<PendingThresholdConfirmation> = []
    private var confirmationTask: Task<Void, Never>?
    private static let confirmationDebounce: Duration = .seconds(3)

    init() {
        let settings = AppSettings(
            legacyClaudeSetupEvidence: AppSettings.hasLegacyClaudeSetupEvidence()
        )
        self.settings = settings
        let enrollment = ProviderEnrollmentStore()
        self.enrollment = enrollment
        // Repair the stable passive-capture symlink after an app move or update
        // only when Claude is enrolled. The installer separately requires the
        // durable managed-capture consent recorded by an explicit installation.
        if enrollment.isEnabled(.claudeCode) {
            ClaudeStatusLineInstaller().repairManagedLinkIfNeeded()
        }
        // Setup-token was experimental and is no longer a credential route.
        // Remove only this app's legacy selection hint; borrowed Claude Code
        // credentials are never modified here.
        UserDefaults.standard.removeObject(forKey: "claude.credential-method.v1")
        let claudeCredentialStore = ClaudeKeychainCredentialStore()
        let claudeOAuthUsageSource = ClaudeOAuthUsageSource(credentialStore: claudeCredentialStore)
        let claudeUsageCache = ClaudeUsageCache()
        self.claudeUsageCache = claudeUsageCache
        claudeSetupState = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .unavailable(reason: ClaudeUsageState.notConnectedReason),
            hasSetupHistory: settings.hasClaudeSetupHistory,
            hasCompletedSourceDiscovery: false
        )
        let monitor = QuotaMonitor(settings: settings, enrollment: enrollment)
        self.monitor = monitor
        let connectionController = CodexConnectionController(
            onConnected: { monitor.refresh(reason: .authentication) },
            // Enrollment is the authority the controller consults; the two
            // former disconnect booleans are gone, so there is one answer to
            // "has the user asked for this provider" rather than two.
            isUserDisconnected: { [enrollment] in !enrollment.isEnabled(.codex) },
            setUserDisconnected: { [enrollment] disconnected in
                if disconnected { enrollment.disable(.codex) } else { enrollment.enable(.codex) }
            }
        )
        self.connectionController = connectionController
        // Claude follows the shared Refresh Preferences like Codex, but its
        // networked OAuth read is floored for endpoint safety.
        let claudeCollector = ClaudeUsageCollector(
            oauthSource: claudeOAuthUsageSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(),
            cache: claudeUsageCache
        )
        let claudeMonitor = ClaudeUsageMonitor(
            collector: claudeCollector,
            cadence: { [settings] in
                ClaudeRefreshCadence.pollInterval(for: settings.refreshMode)
            }
        )
        self.claudeMonitor = claudeMonitor
        let activityMonitor = LocalActivityMonitor()
        self.activityMonitor = activityMonitor
        // Same `.app`-only gate the Codex notifier uses, so tests and previews
        // never touch the notification center.
        self.appNotifier = Bundle.main.bundleURL.pathExtension == "app"
            ? QuotaNotifier(settings: settings)
            : nil
        self.previousThresholds = settings.enabledQuotaThresholdsByProvider
        self.claudeConnectionController = ClaudeConnectionController(
            credentialsSignIn: {
                // Proof of connection is a real usage read. User-initiated, so
                // this is the one path allowed to raise the Keychain prompt.
                let snapshot = try await claudeOAuthUsageSource.fetch(
                    promptPolicy: ClaudeRefreshReason.credentialConnection.keychainPromptPolicy
                )
                return snapshot
            },
            onConnected: { snapshot in
                let previous = claudeUsageCache.load()?.snapshot
                let merged: ClaudeUsageSnapshot
                if snapshot.hasQuotaWindows {
                    merged = snapshot.retainingExtraUsage(from: previous)
                } else if let previous, previous.hasQuotaWindows {
                    merged = previous.retainingExtraUsage(from: snapshot)
                } else {
                    merged = snapshot.retainingExtraUsage(from: previous)
                }
                claudeUsageCache.save(snapshot)
                claudeMonitor.reconnect(
                    with: merged,
                    delivery: snapshot.hasQuotaWindows ? .live : .cached
                )
            },
            onConnectionFailed: {
                // Enrollment and passive capture remain active after a denied
                // or missing credential, so resume noninteractive collection.
                claudeMonitor.reconnect()
            }
        )
        Task { _ = await ClaudeLegacySetupTokenCleanup().removeAppOwnedCredential() }
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
            if case .failed = state,
               self?.runtimePolicy(for: .codex).mayCheckAccount == true {
                self?.connectionController.recheckConnection()
            }
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
        settings.$enabledQuotaThresholdsByProvider.sink { [weak self] newValue in
            self?.handleThresholdChange(newValue)
        }.store(in: &subscriptions)
        claudeMonitor.$state.sink { [weak self] state in
            self?.claudeState = state
            self?.updateClaudeSetupState()
            self?.deliverClaudeThresholdAlerts(for: state)
            if case .available(let presentation) = state,
               presentation.delivery == .live,
               presentation.snapshot.source == .oauth {
                self?.claudeConnectionController.applyLiveOAuthSnapshot(presentation.snapshot)
            }
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
        }.store(in: &subscriptions)
        activityMonitor.$states.sink { [weak self] states in
            self?.localActivityStates = states
        }.store(in: &subscriptions)
        // Hiding an agent's Token Monitor stops reading that agent's records,
        // so visibility has to reach the monitor and not only the menu. Since
        // 0.0.1 the same path also carries enrollment: an unenrolled provider
        // is not read at all, whatever its card preference says.
        settings.$tokenMonitorVisibilityByProvider
            .removeDuplicates()
            .sink { [weak self] visibility in
                guard let self else { return }
                self.applyLocalActivityPolicy(visibility: visibility)
            }.store(in: &subscriptions)
        enrollment.$states
            .removeDuplicates()
            .sink { [weak self] states in
                guard let self else { return }
                self.applyLocalActivityPolicy(enrollmentStates: states)
            }.store(in: &subscriptions)
        // The day/week choice decides how the monitor aggregates, so it has to
        // reach the monitor too. Nothing is reread; the reconciled requests are
        // republished against the new window.
        settings.$tokenMonitorRangeByProvider
            .removeDuplicates()
            .sink { [weak self] ranges in
                guard let self else { return }
                for provider in AgentProvider.allCases {
                    self.activityMonitor.setRange(ranges[provider] ?? .day, for: provider)
                }
            }.store(in: &subscriptions)
        if Self.shouldStartProviderMonitoring(arguments: CommandLine.arguments) {
            start()
        }
    }

    static func shouldStartProviderMonitoring(arguments: [String]) -> Bool {
        !arguments.contains("--live-read-once")
            && !arguments.contains(ClaudeUsageProbeCommand.flag)
            && !arguments.contains(MenuPopoverViabilityGate.launchArgument)
            // Re-opening the tour for visual acceptance must not read a
            // provider, so the preview run is inert in the same way the probes
            // are.
            && !arguments.contains(OnboardingLaunchMode.previewArgument)
    }

    /// The policy every provider's runtime owners are gated on. Enrollment
    /// decides whether an owner may run at all; the individual owners keep
    /// their own separate operational state.
    func runtimePolicy(for provider: AgentProvider) -> ProviderRuntimePolicy {
        ProviderRuntimePolicy.resolve(
            enrollment: enrollment.state(for: provider),
            isTokenMonitorVisible: settings.isTokenMonitorVisible(for: provider)
        )
    }

    private func applyLocalActivityPolicy(
        visibility: [AgentProvider: Bool]? = nil,
        enrollmentStates: [AgentProvider: ProviderEnrollmentState]? = nil
    ) {
        let visibility = visibility ?? settings.tokenMonitorVisibilityByProvider
        let states = enrollmentStates ?? enrollment.states
        for provider in AgentProvider.allCases {
            let policy = ProviderRuntimePolicy.resolve(
                enrollment: states[provider] ?? .notRequested,
                isTokenMonitorVisible: visibility[provider] ?? true
            )
            activityMonitor.setCollectionEnabled(policy.mayCollectLocalActivity, for: provider)
        }
    }

    func localActivityState(for provider: AgentProvider) -> ProviderLocalActivityState {
        localActivityStates[provider] ?? .loading
    }

    var settingsStatus: SettingsStatus {
        SettingsStatus.make(
            displayState: displayState,
            refreshState: refreshState,
            diagnostics: diagnosticSummary
        )
    }

    /// Starts only what the user has explicitly enrolled. Each provider is
    /// evaluated independently, so one enrolled provider never drags the other
    /// into account checks, quota reads, or local scans.
    func start() {
        if runtimePolicy(for: .codex).mayCheckAccount {
            connectionController.start()
            monitor.start()
        }
        // Activity collection is local and costs no tokens, but it is still a
        // read of the user's machine, so since 0.0.1 it waits for that
        // provider's Connect action. The monitor starts either way; the
        // per-provider gate was already applied from `applyLocalActivityPolicy`.
        activityMonitor.start()
        if runtimePolicy(for: .claudeCode).mayRefreshQuota {
            claudeMonitor.start()
        } else {
            // Show disconnected without reading, rather than resuming passive
            // capture.
            claudeMonitor.disconnect()
        }
        Task { [weak self] in
            guard let self else { return }
            _ = await monitor.refreshNotificationAuthorization()
        }
    }

    func refresh() {
        guard runtimePolicy(for: .codex).mayRefreshQuota else { return }
        monitor.refresh(reason: .manual)
    }

    /// The explicit Codex enrollment action. It records consent for Codex only,
    /// then hands off to the existing controller — which may adopt an already
    /// authenticated CLI session, because consent is now on record.
    func connectCodex() {
        guard !enrollment.isEnabled(.codex) else { return }
        enrollment.enable(.codex)
        connectionController.start()
        // `start()` performs the launch refresh on a first enrollment. A
        // re-enrollment after Disconnect finds the monitor already started, and
        // the enrollment transition it just published drives that refresh.
        monitor.start()
    }

    /// The explicit Claude enrollment action. Enrolling alone raises no Keychain
    /// prompt; the credential read it delegates to is the user-initiated step
    /// that may.
    func connectClaude() {
        claudeCLIProbeGeneration += 1
        enrollment.enable(.claudeCode)
        // Enroll passive capture at the same time. A foreign status line is
        // preserved, and a repairable command still requires confirmation.
        configureClaudePassiveCapture(replacingExisting: false)
        Task { [weak self] in
            guard let self else { return }
            await claudeMonitor.prepareForConnection()
            guard enrollment.isEnabled(.claudeCode) else { return }
            claudeConnectionController.connect()
        }
    }

    /// User-initiated from Diagnostics: drop the recorded refresh history.
    func clearRefreshDiagnostics() {
        monitor.clearDiagnostics()
    }

    func checkCodexConnection() {
        guard runtimePolicy(for: .codex).mayCheckAccount else { return }
        connectionController.checkConnection()
    }

    /// App-local disconnect: hide Codex usage and stop auto-detecting, leaving
    /// the Codex CLI session and stored credential untouched. The controller
    /// records `.disabled` through its `setUserDisconnected` closure, which also
    /// stops the quota owner and purges Codex's derived local-activity cache.
    func disconnectCodex() {
        connectionController.disconnect()
    }

    func signInWithBrowser() {
        guard runtimePolicy(for: .codex).mayCheckAccount else { return }
        connectionController.signInWithBrowser()
    }

    func signInWithCLI() {
        guard runtimePolicy(for: .codex).mayCheckAccount else { return }
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

    /// User-initiated refresh bypasses eligible back-off/coalescing, but still
    /// forbids Keychain interaction. Only Connect may prompt.
    func refreshClaude() {
        guard runtimePolicy(for: .claudeCode).mayRefreshQuota else { return }
        Task { [claudeMonitor] in
            await claudeMonitor.refreshNow(reason: .userInitiated)
        }
    }

    /// Passive capture is the only Claude source that costs nothing and needs
    /// no credential, so its health is surfaced rather than left silent — it
    /// was dead in production for weeks while the app said nothing.
    @Published private(set) var claudePassiveCapture: ClaudePassiveCaptureHealth?

    func refreshClaudePassiveCaptureHealth() {
        let installer = ClaudeStatusLineInstaller()
        claudePassiveCapture = ClaudePassiveCaptureHealth(
            state: installer.inspect(),
            lastCapturedAt: ClaudeRateLimitSnapshotReader().readSnapshot()?.capturedAt
        )
    }

    /// Installs passive capture, or repairs a status line this project left
    /// behind. `replacingExisting` is the user's explicit confirmation; a
    /// working third-party status line is never replaced either way.
    func configureClaudePassiveCapture(replacingExisting: Bool) {
        _ = ClaudeStatusLineInstaller().install(replacingExisting: replacingExisting)
        refreshClaudePassiveCaptureHealth()
    }

    /// Explicit user action — the only path that may raise the Keychain
    /// prompt for Claude Code's credential.
    /// App-local disconnect: hide Claude usage (including passive capture) and
    /// reset the connection, leaving the Claude Code Keychain credential intact.
    /// Recording `.disabled` also stops Claude's local reads and purges its
    /// derived Token Monitor cache through the existing privacy path.
    func disconnectClaude() {
        claudeCLIProbeGeneration += 1
        claudeConnectionController.disconnect()
        let cancelledRefresh = claudeMonitor.disconnect()
        enrollment.disable(.claudeCode)
        ClaudeStatusLineInstaller().uninstallManagedCapture()
        claudePassiveCapture = nil
        Task { [weak self] in
            _ = await cancelledRefresh?.value
            guard let self, !enrollment.isEnabled(.claudeCode) else { return }
            try? claudeUsageCache.delete()
        }
    }

    /// Tier 2. Manual only, and only after the user has consented to the
    /// token cost — never called from a scheduled refresh.
    func runClaudeCLIProbe() {
        guard runtimePolicy(for: .claudeCode).mayRefreshQuota else { return }
        guard !isRunningClaudeCLIProbe else { return }
        isRunningClaudeCLIProbe = true
        claudeCLIProbeError = nil
        let generation = claudeCLIProbeGeneration
        Task { [weak self] in
            guard let self else { return }
            defer { isRunningClaudeCLIProbe = false }
            do {
                let snapshot = try await ClaudeCLIUsageProbe().run()
                guard generation == claudeCLIProbeGeneration,
                      enrollment.isEnabled(.claudeCode) else { return }
                claudeUsageCache.save(snapshot)
                claudeMonitor.applyManualSnapshot(snapshot)
            } catch {
                guard generation == claudeCLIProbeGeneration,
                      enrollment.isEnabled(.claudeCode) else { return }
                claudeCLIProbeError = Self.cliProbeMessage(for: error)
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

    /// Evaluates current Claude readings only. The notifier retains ownership
    /// of threshold settings and reset-window deduplication.
    private func deliverClaudeThresholdAlerts(for state: ClaudeUsageState) {
        guard let appNotifier,
              case .available(let presentation) = state,
              let windows = Self.claudeThresholdWindows(for: presentation) else { return }
        Task {
            await appNotifier.evaluateClaudeThresholds(
                fiveHour: windows.fiveHour,
                weekly: windows.weekly
            )
        }
    }

    /// Collects newly-enabled thresholds and, after a short quiet period, sends
    /// one confirmation summarizing them. A threshold turned on then off within
    /// the window cancels out, so no confirmation is sent for it.
    private func handleThresholdChange(_ newValue: [AgentProvider: Set<RemainingQuotaThreshold>]) {
        for provider in AppSettings.quotaThresholdProviders {
            let old = previousThresholds[provider] ?? []
            let new = newValue[provider] ?? []
            for added in new.subtracting(old) {
                pendingConfirmations.insert(PendingThresholdConfirmation(provider: provider, threshold: added))
            }
            for removed in old.subtracting(new) {
                pendingConfirmations.remove(PendingThresholdConfirmation(provider: provider, threshold: removed))
            }
        }
        previousThresholds = newValue

        confirmationTask?.cancel()
        guard appNotifier != nil, !pendingConfirmations.isEmpty else { return }
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(for: Self.confirmationDebounce)
            guard !Task.isCancelled else { return }
            await self?.flushThresholdConfirmations()
        }
    }

    private func flushThresholdConfirmations() async {
        let pending = pendingConfirmations
        pendingConfirmations = []
        guard let body = ThresholdConfirmationMessage.body(for: Array(pending)) else { return }
        await appNotifier?.deliverConfirmation(body)
    }

    nonisolated static func claudeThresholdWindows(
        for presentation: ClaudeUsagePresentation,
        now: Date = .now
    ) -> (fiveHour: QuotaWindow?, weekly: QuotaWindow?)? {
        let eligible = switch (presentation.delivery, presentation.snapshot.source) {
        case (.live, .oauth), (.live, .cli): true
        case (.passiveSnapshot, .statusLine): presentation.isFreshPassive(at: now)
        default: false
        }
        guard eligible else { return nil }
        return (
            claudeThresholdWindow(presentation.snapshot.fiveHour, now: now),
            claudeThresholdWindow(presentation.snapshot.sevenDay, now: now)
        )
    }

    nonisolated private static func claudeThresholdWindow(
        _ window: ClaudeLimitWindow?,
        now: Date
    ) -> QuotaWindow? {
        guard let window, let resetAt = window.resetsAt, resetAt > now else { return nil }
        return QuotaWindow(
            usedPercent: Int(window.usedPercent.rounded()),
            resetAt: resetAt,
            durationMinutes: nil
        )
    }
}
