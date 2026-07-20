import Foundation

final class ClaudeRateLimitSnapshotReader {
    private let fileURL: URL
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.fileURL = support.appendingPathComponent("CodexUsageMonitor/claude-rate-limits.json")
        self.decoder = JSONDecoder()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.decoder = JSONDecoder()
    }

    /// Reads the bridge-written snapshot, or nil if it is missing, malformed,
    /// or on an unrecognized schema version. Never throws: this mirrors
    /// QuotaHistoryStore's read-only-best-effort behavior — a missing or
    /// corrupt snapshot must never crash or block the caller.
    func readSnapshot() -> ClaudeRateLimitSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(ClaudeRateLimitSnapshot.self, from: data),
              snapshot.schemaVersion == 1
        else { return nil }
        return snapshot
    }
}
