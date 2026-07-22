import Foundation

/// Cache metadata separate from the snapshot's own `source` field: `source`
/// says where the data originated (oauth/statusLine), this wrapper is only
/// about when it was saved to disk.
struct ClaudeCachedUsage: Codable, Equatable {
    let snapshot: ClaudeUsageSnapshot
    let savedAt: Date
}

/// Stores only normalized, non-secret usage data — this type has no token
/// fields to accidentally cache because ClaudeUsageSnapshot has none.
struct ClaudeUsageCache {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.fileURL = support.appendingPathComponent("CodexUsageMonitor/claude-usage-cache.json")
    }

    func load() -> ClaudeCachedUsage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ClaudeCachedUsage.self, from: data)
    }

    func save(_ snapshot: ClaudeUsageSnapshot) {
        // Last-known-*good* means most recent good. A degraded refresh falling
        // back to an old statusLine capture must not overwrite a fresher
        // result — otherwise the cache decays instead of preserving the best
        // reading we have.
        if let existing = load(), existing.snapshot.capturedAt > snapshot.capturedAt {
            return
        }
        let cached = ClaudeCachedUsage(snapshot: snapshot, savedAt: .now)
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try JSONEncoder().encode(cached)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Cache is best-effort and must never make a refresh fail.
        }
    }
}
