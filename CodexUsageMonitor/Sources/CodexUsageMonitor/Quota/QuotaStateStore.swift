import Foundation

struct StoredQuota: Codable, Sendable {
    let savedAt: Date
    let presentation: QuotaPresentation
}

final class QuotaStateStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        fileURL = support.appendingPathComponent("CodexUsageMonitor/last-known-good.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> StoredQuota? {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? decoder.decode(StoredQuota.self, from: data),
              stored.presentation.accountFingerprint != nil,
              stored.presentation.limitID == "codex"
        else { return nil }
        return stored
    }

    func save(_ presentation: QuotaPresentation) {
        guard presentation.accountFingerprint != nil,
              presentation.limitID == "codex",
              presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry
        else { return }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try encoder.encode(StoredQuota(savedAt: .now, presentation: presentation))
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Cache writes are intentionally best-effort: quota collection remains read-only.
        }
    }
}
