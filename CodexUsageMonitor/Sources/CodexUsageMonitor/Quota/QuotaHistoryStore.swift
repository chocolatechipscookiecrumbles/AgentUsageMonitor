import Foundation

private struct StoredQuotaHistory: Codable {
    let schemaVersion: Int
    let entries: [QuotaHistoryEntry]
}

final class QuotaHistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retention: TimeInterval = 90 * 24 * 3_600
    private let maximumEntries = 500

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        fileURL = support.appendingPathComponent("CodexUsageMonitor/quota-history.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func entries(matching presentation: QuotaPresentation) -> [QuotaHistoryEntry] {
        guard let fingerprint = presentation.accountFingerprint,
              let limitID = presentation.limitID
        else { return [] }
        return load().filter {
            $0.providerID == QuotaHistoryEntry.providerID &&
                $0.accountFingerprint == fingerprint &&
                $0.limitID == limitID
        }
    }

    func append(_ entry: QuotaHistoryEntry) {
        var entries = load()
        guard !entries.contains(where: { isDuplicate($0, entry) }) else { return }
        entries.append(entry)
        entries = prune(entries)
        save(entries)
    }

    private func load() -> [QuotaHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? decoder.decode(StoredQuotaHistory.self, from: data),
              stored.schemaVersion == 1
        else { return [] }
        return prune(stored.entries)
    }

    private func isDuplicate(_ first: QuotaHistoryEntry, _ second: QuotaHistoryEntry) -> Bool {
        first.providerID == second.providerID &&
            first.accountFingerprint == second.accountFingerprint &&
            first.limitID == second.limitID &&
            first.collectedAt == second.collectedAt &&
            first.fiveHour.resetAt == second.fiveHour.resetAt &&
            first.weekly.resetAt == second.weekly.resetAt
    }

    private func prune(_ entries: [QuotaHistoryEntry]) -> [QuotaHistoryEntry] {
        let cutoff = Date().addingTimeInterval(-retention)
        return entries.filter { $0.collectedAt >= cutoff }
            .sorted { $0.collectedAt < $1.collectedAt }
            .suffix(maximumEntries)
            .map { $0 }
    }

    private func save(_ entries: [QuotaHistoryEntry]) {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try encoder.encode(StoredQuotaHistory(schemaVersion: 1, entries: entries))
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // History is best-effort and must never make the read-only collector fail.
        }
    }
}
