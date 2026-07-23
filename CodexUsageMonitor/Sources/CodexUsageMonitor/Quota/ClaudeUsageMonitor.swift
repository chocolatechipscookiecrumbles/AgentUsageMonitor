import Foundation

/// Seam so the monitor can be driven by a fake in tests without reaching the
/// Keychain, the network, or the filesystem.
protocol ClaudeUsageCollecting: Sendable {
    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation
}

extension ClaudeUsageCollector: ClaudeUsageCollecting {}

@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    /// Network-appropriate: a refresh can now reach the OAuth endpoint, so the
    /// old 30s local-file cadence would mean an API call every 30 seconds.
    /// The collector's own fallback order handles the cheap statusLine/cache
    /// paths within each refresh, so this only paces the expensive one.
    static let defaultPollInterval: Duration = .seconds(12 * 60)

    @Published private(set) var state: ClaudeUsageState = .unavailable(reason: ClaudeUsageState.notConnectedReason)
    @Published private(set) var hasCompletedInitialRefresh = false

    private let collector: ClaudeUsageCollecting
    private let pollInterval: Duration
    private var pollTask: Task<Void, Never>?

    init(
        collector: ClaudeUsageCollecting = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(credentialStore: ClaudeCompositeCredentialStore()),
            statusLineReader: ClaudeRateLimitSnapshotReader(),
            cache: ClaudeUsageCache()
        ),
        pollInterval: Duration = ClaudeUsageMonitor.defaultPollInterval
    ) {
        self.collector = collector
        self.pollInterval = pollInterval
    }

    deinit {
        pollTask?.cancel()
    }

    /// Refreshes once immediately so callers see a state without waiting a
    /// full interval, then re-refreshes on the configured cadence.
    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Checked before the launch refresh too: stopping immediately
            // after starting must prevent the read, not just later polls.
            guard !Task.isCancelled else { return }
            await refreshNow(reason: .appLaunch)
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { return }
                await self.refreshNow(reason: .scheduled)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// The reason is load-bearing: it decides whether the Keychain read is
    /// allowed to prompt (only `.userInitiated` is).
    func refreshNow(reason: ClaudeRefreshReason) async {
        let presentation = await collector.refresh(reason: reason)
        state = Self.mapState(presentation)
        hasCompletedInitialRefresh = true
    }

    /// Publishes a snapshot obtained outside the automatic hierarchy — the
    /// user-initiated CLI probe. Marked `.live` because the user just paid
    /// tokens for a fresh reading.
    func applyManualSnapshot(_ snapshot: ClaudeUsageSnapshot) {
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
