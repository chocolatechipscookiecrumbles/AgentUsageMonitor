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
    private var isPausedForConnection = false
    /// Invalidates refresh completions that belong to an earlier enrollment or
    /// connection attempt, even when their underlying work returns after
    /// cancellation and the current lifecycle has already resumed.
    private var lifecycleGeneration = 0

    private let collector: ClaudeUsageCollecting
    /// Evaluated before each scheduled poll so a live change to the shared
    /// Refresh Preferences takes effect without restarting the monitor.
    private let pollInterval: @MainActor () -> Duration
    private var pollTask: Task<Void, Never>?
    /// The refresh currently running, with the reason that started it, so a
    /// user action can tell whether waiting for it is enough.
    private var inFlight: (task: Task<Void, Never>, reason: ClaudeRefreshReason)?

    init(
        collector: ClaudeUsageCollecting,
        pollInterval: Duration = ClaudeUsageMonitor.defaultPollInterval
    ) {
        self.collector = collector
        self.pollInterval = { pollInterval }
    }

    /// Production initializer: the poll cadence follows the shared `RefreshMode`
    /// setting (clamped to Claude's network floor) and is re-read each tick.
    init(
        collector: ClaudeUsageCollecting,
        cadence: @escaping @MainActor () -> Duration
    ) {
        self.collector = collector
        self.pollInterval = cadence
    }

    deinit {
        pollTask?.cancel()
        inFlight?.task.cancel()
    }

    /// Refreshes once immediately so callers see a state without waiting a
    /// full interval, then re-refreshes on the configured cadence.
    func start() {
        startPolling(refreshImmediately: true)
    }

    private func startPolling(refreshImmediately: Bool) {
        guard !isDisconnected, !isPausedForConnection else { return }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Checked before the launch refresh too: stopping immediately
            // after starting must prevent the read, not just later polls.
            guard !Task.isCancelled else { return }
            if refreshImmediately {
                await refreshNow(reason: .appLaunch)
            }
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

    /// Quiesces monitor-owned reads before the one interactive credential
    /// connection begins. This keeps a reconnect from racing an automatic read.
    func prepareForConnection() async {
        lifecycleGeneration += 1
        isPausedForConnection = true
        stop()
        guard let refresh = inFlight?.task else { return }
        refresh.cancel()
        _ = await refresh.value
        if inFlight?.task == refresh {
            inFlight = nil
            isRefreshing = false
        }
    }

    /// App-local disconnect: stop reading and show the disconnected state
    /// without touching the Keychain credential.
    @discardableResult
    func disconnect() -> Task<Void, Never>? {
        lifecycleGeneration += 1
        isDisconnected = true
        isPausedForConnection = false
        stop()
        let cancelledRefresh = inFlight?.task
        cancelledRefresh?.cancel()
        inFlight = nil
        isRefreshing = false
        state = .unavailable(reason: Self.disconnectedReason)
        hasCompletedInitialRefresh = true
        return cancelledRefresh
    }

    /// Clears the disconnect and resumes passive capture.
    func reconnect() {
        isDisconnected = false
        isPausedForConnection = false
        start()
    }

    /// Connect already performed the authoritative OAuth read. Publish that
    /// exact result and begin at the next cadence boundary instead of issuing a
    /// duplicate read (and potentially a second Keychain prompt) immediately.
    func reconnect(
        with snapshot: ClaudeUsageSnapshot,
        delivery: ClaudeUsageDelivery = .live
    ) {
        isDisconnected = false
        isPausedForConnection = false
        let snapshot = snapshot.retainingExtraUsage(from: state.presentation?.snapshot)
        state = Self.mapState(
            ClaudeUsagePresentation(snapshot: snapshot, delivery: delivery, warnings: [])
        )
        hasCompletedInitialRefresh = true
        startPolling(refreshImmediately: false)
    }

    /// The reason is load-bearing for back-off and coalescing. Monitor-owned
    /// refreshes never prompt; only the separate credential connection does.
    ///
    /// A refresh already in flight used to make this return immediately. That
    /// silently discarded the user's press whenever it landed inside a
    /// scheduled read's network window — no read, no state change, no message —
    /// while an automatic refresh was still coalesced. An automatic refresh
    /// still coalesces; a press never does.
    func refreshNow(reason: ClaudeRefreshReason) async {
        let generation = lifecycleGeneration
        guard !isDisconnected, !isPausedForConnection else { return }

        while let existing = inFlight {
            guard reason == .userInitiated else { return }
            _ = await existing.task.value
            guard generation == lifecycleGeneration,
                  !isDisconnected,
                  !isPausedForConnection else { return }
            // A press already running produces exactly what this press would,
            // so waiting for it is the whole obligation — starting a second
            // read would only duplicate the same explicit action.
            if existing.reason == .userInitiated { return }
            if inFlight?.task == existing.task { inFlight = nil }
        }

        guard generation == lifecycleGeneration,
              !isDisconnected,
              !isPausedForConnection else { return }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !Task.isCancelled,
                  generation == self.lifecycleGeneration,
                  !self.isDisconnected,
                  !self.isPausedForConnection else { return }
            let presentation = await self.collector.refresh(reason: reason)
            guard generation == self.lifecycleGeneration,
                  !self.isDisconnected,
                  !self.isPausedForConnection else { return }
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
        // An older in-flight fallback must not replace this explicit reading.
        lifecycleGeneration += 1
        inFlight?.task.cancel()
        inFlight = nil
        isRefreshing = false
        let snapshot = snapshot.retainingExtraUsage(from: state.presentation?.snapshot)
        state = Self.mapState(
            ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
        )
    }

    /// A financial-only observation remains visible while its quota windows
    /// stay unavailable. A completely empty reading must not invent data.
    private static func mapState(_ presentation: ClaudeUsagePresentation) -> ClaudeUsageState {
        let hasData = presentation.snapshot.hasQuotaWindows || presentation.snapshot.extraUsage != nil
        guard hasData else {
            return .unavailable(reason: presentation.warnings.first ?? ClaudeUsageState.notConnectedReason)
        }
        return .available(presentation)
    }
}
