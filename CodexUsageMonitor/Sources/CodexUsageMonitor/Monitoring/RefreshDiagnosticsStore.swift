import Foundation

enum RefreshOutcome: String, Codable, Sendable {
    case confirmed
    case confirmedAfterRetry = "confirmed-after-retry"
    case cachedLastKnownGood = "cached-last-known-good"
    case unconfirmed
    case unavailable
}

struct RefreshDiagnostic: Codable, Sendable {
    let startedAt: Date
    let completedAt: Date
    let reason: RefreshReason
    let outcome: RefreshOutcome
    let failureKind: String?
}

struct RefreshDiagnosticSummary: Sendable {
    let outcomes: [RefreshOutcome: Int]
    let failureKinds: [String: Int]
}

private struct StoredRefreshDiagnostics: Codable {
    let schemaVersion: Int
    let entries: [RefreshDiagnostic]
}

final class RefreshDiagnosticsStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retention: TimeInterval = 30 * 24 * 3_600
    private let maximumEntries = 1_000

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        fileURL = support.appendingPathComponent("CodexUsageMonitor/refresh-diagnostics.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func append(_ entry: RefreshDiagnostic) {
        var entries = load()
        entries.append(entry)
        save(prune(entries))
    }

    func diagnosticSummary(from start: Date, through end: Date) -> RefreshDiagnosticSummary {
        let matching = load().filter { $0.completedAt >= start && $0.completedAt <= end }
        return RefreshDiagnosticSummary(
            outcomes: Dictionary(grouping: matching, by: \.outcome).mapValues(\.count),
            failureKinds: Dictionary(grouping: matching.compactMap(\.failureKind), by: { $0 }).mapValues(\.count)
        )
    }

    private func load() -> [RefreshDiagnostic] {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? decoder.decode(StoredRefreshDiagnostics.self, from: data),
              stored.schemaVersion == 1
        else { return [] }
        return prune(stored.entries)
    }

    private func prune(_ entries: [RefreshDiagnostic]) -> [RefreshDiagnostic] {
        let cutoff = Date().addingTimeInterval(-retention)
        return entries.filter { $0.completedAt >= cutoff }
            .sorted { $0.completedAt < $1.completedAt }
            .suffix(maximumEntries)
            .map { $0 }
    }

    private func save(_ entries: [RefreshDiagnostic]) {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try encoder.encode(StoredRefreshDiagnostics(schemaVersion: 1, entries: entries))
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Diagnostics are best-effort and must never interfere with quota refreshes.
        }
    }
}
