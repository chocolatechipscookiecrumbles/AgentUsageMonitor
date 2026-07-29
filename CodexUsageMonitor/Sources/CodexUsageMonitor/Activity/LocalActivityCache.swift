import Foundation

/// Carries reconciled activity across launches so the card shows the previous
/// instance's result immediately instead of rebuilding from nothing every time.
///
/// It stores only values the card already displays: hashed request identities,
/// timestamps, model identifiers, and token counts. There is no file path, no
/// provider session or event identifier, no raw record, and nothing that could
/// reconstruct a conversation. A background rescan still runs at launch and
/// replaces this the moment it finishes, so the cache is a head start rather
/// than a source of truth.
struct LocalActivityCachedRequests: Codable, Equatable {
    /// Bumped when the reconciliation contract changes, so a build that counts
    /// differently never renders another build's numbers.
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let provider: AgentProvider
    let savedAt: Date
    let requests: [LocalActivityRequest]
}

struct LocalActivityCache {
    /// Enough history for the widest window the card can report — the current
    /// local week — plus room for a week rollover and a time-zone change,
    /// without carrying months of requests that no longer affect anything on
    /// screen. A scan still rebuilds the real set from local records; this only
    /// bounds what the previous launch may hand forward.
    static let retention: TimeInterval = 14 * 24 * 60 * 60

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        fileURL = support.appendingPathComponent("CodexUsageMonitor/token-activity-cache.json")
    }

    func load() -> [AgentProvider: [LocalActivityRequest]] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([LocalActivityCachedRequests].self, from: data)
        else { return [:] }

        var result: [AgentProvider: [LocalActivityRequest]] = [:]
        for entry in entries {
            guard entry.schemaVersion == LocalActivityCachedRequests.currentSchemaVersion,
                  entry.requests.allSatisfy({ isTrustworthy($0, provider: entry.provider) }),
                  Set(entry.requests.map(\.id)).count == entry.requests.count
            else { continue }
            result[entry.provider] = entry.requests
        }
        return result
    }

    /// Writes one provider's entry, leaving every other provider's on disk.
    ///
    /// Whole-map writes are unsafe here: the monitor deliberately drops a
    /// provider whose scan was unsafe to read while leaving its cached history
    /// alone, so rewriting the file from in-memory state would erase exactly
    /// the entry that was meant to survive.
    func update(_ provider: AgentProvider, requests: [LocalActivityRequest]?, now: Date = .now) {
        var entries = load()
        if let requests {
            entries[provider] = requests
        } else {
            guard entries[provider] != nil else { return }
            entries[provider] = nil
        }
        save(entries, now: now)
    }

    func save(_ requestsByProvider: [AgentProvider: [LocalActivityRequest]], now: Date = .now) {
        let entries = requestsByProvider.map { provider, requests in
            LocalActivityCachedRequests(
                schemaVersion: LocalActivityCachedRequests.currentSchemaVersion,
                provider: provider,
                savedAt: now,
                requests: retained(requests, now: now)
            )
        }
        .sorted { $0.provider.rawValue < $1.provider.rawValue }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // The cache is best-effort. Failing to write it must never affect
            // what the app already reconciled in memory.
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Keeps the recent window plus the single newest request, so Last Request
    /// still has an answer after a long gap in usage without storing the whole
    /// history behind it.
    private func retained(_ requests: [LocalActivityRequest], now: Date) -> [LocalActivityRequest] {
        let cutoff = now.addingTimeInterval(-Self.retention)
        var kept = requests.filter { $0.occurredAt >= cutoff }
        if kept.isEmpty,
           let newest = requests.max(by: { $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt < $1.occurredAt }) {
            kept = [newest]
        }
        return kept.sorted { $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt < $1.occurredAt }
    }

    /// Synthesized decoding writes stored properties directly, bypassing the
    /// validation that construction normally enforces. Re-deriving the total
    /// keeps an edited or truncated cache from becoming plausible activity.
    private func isTrustworthy(_ request: LocalActivityRequest, provider: AgentProvider) -> Bool {
        guard request.provider == provider else { return false }
        let revalidated = LocalActivityTokenBreakdown(
            provider: provider,
            inputTokens: request.tokens.inputTokens,
            cacheCreationTokens: request.tokens.cacheCreationTokens,
            cachedInputTokens: request.tokens.cachedInputTokens,
            outputTokens: request.tokens.outputTokens,
            reasoningOutputTokens: request.tokens.reasoningOutputTokens,
            reportedTotalTokens: request.tokens.totalTokens
        )
        return revalidated == request.tokens
    }
}
