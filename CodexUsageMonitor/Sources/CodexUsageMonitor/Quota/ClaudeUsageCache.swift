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
    // ponytail: one lock serializes cache writes; use per-file locks only if
    // multiple independent Claude caches make this a measurable bottleneck.
    private static let writeLock = NSLock()
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
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        // Quota and financial observations have independent ages. Keep the
        // newest quota while merging spending by its own observation time.
        let existing = load()
        let merged: ClaudeUsageSnapshot
        if let existing, existing.snapshot.hasQuotaWindows,
           !snapshot.hasQuotaWindows || existing.snapshot.capturedAt > snapshot.capturedAt {
            merged = existing.snapshot.retainingExtraUsage(from: snapshot)
        } else {
            merged = snapshot.retainingExtraUsage(from: existing?.snapshot)
        }
        let cached = ClaudeCachedUsage(snapshot: merged, savedAt: .now)
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

    func delete() throws {
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}
