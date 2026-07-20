import Foundation

@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    @Published private(set) var state: ClaudeUsageState = .notAvailable

    private let reader: ClaudeRateLimitSnapshotReader
    private let pollInterval: Duration
    private var pollTask: Task<Void, Never>?

    init(reader: ClaudeRateLimitSnapshotReader = ClaudeRateLimitSnapshotReader(), pollInterval: Duration = .seconds(30)) {
        self.reader = reader
        self.pollInterval = pollInterval
    }

    deinit {
        pollTask?.cancel()
    }

    /// Starts polling. Reads once immediately so callers see a state without
    /// waiting a full interval, then re-reads on the configured cadence.
    /// Polling only re-reads a small local file — unlike Codex's network
    /// refresh, this carries no cost or rate-limit concern at any interval.
    func start() {
        guard pollTask == nil else { return }
        refreshNow()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { return }
                await self.refreshNow()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshNow() {
        if let snapshot = reader.readSnapshot() {
            state = .available(snapshot)
        } else {
            state = .notAvailable
        }
    }
}
