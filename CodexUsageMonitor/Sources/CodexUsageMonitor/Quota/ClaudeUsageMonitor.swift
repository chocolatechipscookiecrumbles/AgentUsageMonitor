import Foundation

/// Seam so the monitor can be driven by a fake in tests without reaching the
/// Keychain, the network, or the filesystem.
protocol ClaudeUsageCollecting: Sendable {
    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation
}

extension ClaudeUsageCollector: ClaudeUsageCollecting {}

@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    /// Fallback cadence for the fixed-interval initializer (tests and any caller
    /// that does not supply a `cadence`). Production derives the interval from the
    /// shared `RefreshMode` via `ClaudeRefreshCadence`, which floors the networked
    /// OAuth read for endpoint safety; this constant stays network-appropriate for
    /// the plain fixed-interval path.
    static let defaultPollInterval: Duration = .seconds(12 * 60)

    @Published private(set) var state: ClaudeUsageState = .unavailable(reason: ClaudeUsageState.notConnectedReason)
    @Published private(set) var hasCompletedInitialRefresh = false
    @Published private(set) var isRefreshing = false

    /// App-local disconnect: while set, the monitor stops reading and publishes
    /// an explicit disconnected state, so passive capture does not keep showing
    /// Claude usage after the user disconnects. The Keychain credential itself
    /// is never touched.
    static let disconnectedReason = "Claude is disconnected. Reconnect to show usage."
    private var isDisconnected = false

    private let collector: ClaudeUsageCollecting
    /// Evaluated before each scheduled poll so a live change to the shared
    /// Refresh Preferences takes effect without restarting the monitor.
    private let pollInterval: @MainActor () -> Duration
    private var pollTask: Task<Void, Never>?
    /// The refresh currently running, with the reason that started it, so a
    /// user action can tell whether waiting for it is enough.
    private var inFlight: (task: Task<Void, Never>, reason: ClaudeRefreshReason)?

    init(
        collector: ClaudeUsageCollecting = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(credentialStore: ClaudeCompositeCredentialStore()),
            statusLineReader: ClaudeRateLimitSnapshotReader(),
            cache: ClaudeUsageCache(),
            delegatedRefresh: ClaudeDelegatedRefreshCoordinator()
        ),
        pollInterval: Duration = ClaudeUsageMonitor.defaultPollInterval
    ) {
        self.collector = collector
        self.pollInterval = { pollInterval }
    }

    /// Production initializer: the poll cadence follows the shared `RefreshMode`
    /// setting (clamped to Claude's network floor) and is re-read each tick.
    init(
        collector: ClaudeUsageCollecting = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(credentialStore: ClaudeCompositeCredentialStore()),
            statusLineReader: ClaudeRateLimitSnapshotReader(),
            cache: ClaudeUsageCache(),
            delegatedRefresh: ClaudeDelegatedRefreshCoordinator()
        ),
        cadence: @escaping @MainActor () -> Duration
    ) {
        self.collector = collector
        self.pollInterval = cadence
    }

    deinit {
        pollTask?.cancel()
    }

    /// Refreshes once immediately so callers see a state without waiting a
    /// full interval, then re-refreshes on the configured cadence.
    func start() {
        guard !isDisconnected else { return }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Checked before the launch refresh too: stopping immediately
            // after starting must prevent the read, not just later polls.
            guard !Task.isCancelled else { return }
            await refreshNow(reason: .appLaunch)
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval())
                guard !Task.isCancelled else { return }
                await self.refreshNow(reason: .scheduled)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// App-local disconnect: stop reading and show the disconnected state
    /// without touching the Keychain credential.
    func disconnect() {
        isDisconnected = true
        stop()
        state = .unavailable(reason: Self.disconnectedReason)
        hasCompletedInitialRefresh = true
    }

    /// Clears the disconnect and resumes passive capture.
    func reconnect() {
        guard isDisconnected else { return }
        isDisconnected = false
        start()
    }

    /// The reason is load-bearing: it decides whether the Keychain read is
    /// allowed to prompt (only `.userInitiated` is).
    ///
    /// A refresh already in flight used to make this return immediately. That
    /// silently discarded the user's press whenever it landed inside a
    /// scheduled read's network window — no read, no state change, no message —
    /// and the press was exactly the one refresh permitted to raise the
    /// Keychain dialog. An automatic refresh still coalesces; a press never
    /// does.
    func refreshNow(reason: ClaudeRefreshReason) async {
        guard !isDisconnected else { return }

        while let existing = inFlight {
            guard reason == .userInitiated else { return }
            _ = await existing.task.value
            // A press already running produces exactly what this press would,
            // so waiting for it is the whole obligation — starting a second
            // read would only mean a second permission dialog.
            if existing.reason == .userInitiated { return }
            if inFlight?.task == existing.task { inFlight = nil }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let presentation = await self.collector.refresh(reason: reason)
            guard !self.isDisconnected else { return }
            self.state = Self.mapState(presentation)
            self.hasCompletedInitialRefresh = true
        }
        inFlight = (task, reason)
        isRefreshing = true
        _ = await task.value
        if inFlight?.task == task {
            inFlight = nil
            isRefreshing = false
        }
    }

    /// Publishes a snapshot obtained outside the automatic hierarchy — the
    /// user-initiated CLI probe. Marked `.live` because the user just paid
    /// tokens for a fresh reading.
    func applyManualSnapshot(_ snapshot: ClaudeUsageSnapshot) {
        guard !isDisconnected else { return }
        state = Self.mapState(
            ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
        )
    }

    /// A presentation with no windows at all is the collector's "no usable
    /// source" case — it must surface as an explicit unavailable state, never
    /// as a zeroed quota (capability gate criterion #5).
    private static func mapState(_ presentation: ClaudeUsagePresentation) -> ClaudeUsageState {
        let hasData = presentation.snapshot.fiveHour != nil
            || presentation.snapshot.sevenDay != nil
            || !presentation.snapshot.scopedWindows.isEmpty
        guard hasData else {
            return .unavailable(reason: presentation.warnings.first ?? ClaudeUsageState.notConnectedReason)
        }
        return .available(presentation)
    }
}
