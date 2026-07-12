import Foundation

enum QuotaWindowKind: String, Codable, Sendable {
    case fiveHour
    case weekly
}

struct QuotaHistoryEntry: Codable, Equatable, Sendable {
    static let providerID = "codex"

    let providerID: String
    let accountFingerprint: String
    let limitID: String
    let collectedAt: Date
    let fiveHour: QuotaWindow
    let weekly: QuotaWindow

    init?(presentation: QuotaPresentation) {
        guard presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry,
              let accountFingerprint = presentation.accountFingerprint,
              let limitID = presentation.limitID,
              let fiveHour = presentation.fiveHour,
              let weekly = presentation.weekly,
              fiveHour.resetAt != nil,
              weekly.resetAt != nil
        else { return nil }
        self.providerID = Self.providerID
        self.accountFingerprint = accountFingerprint
        self.limitID = limitID
        self.collectedAt = presentation.collectedAt
        self.fiveHour = fiveHour
        self.weekly = weekly
    }

    func window(_ kind: QuotaWindowKind) -> QuotaWindow {
        switch kind {
        case .fiveHour: fiveHour
        case .weekly: weekly
        }
    }
}

struct QuotaForecast: Codable, Equatable, Sendable {
    let projectedExhaustionAt: Date
    let resetAt: Date
    let percentPerHour: Double

    static func calculate(
        for kind: QuotaWindowKind,
        current: QuotaHistoryEntry,
        entries: [QuotaHistoryEntry]
    ) -> QuotaForecast? {
        let currentWindow = current.window(kind)
        guard let resetAt = currentWindow.resetAt else { return nil }
        let matching = entries.filter { entry in
            guard entry.providerID == current.providerID,
                  entry.accountFingerprint == current.accountFingerprint,
                  entry.limitID == current.limitID,
                  let candidateReset = entry.window(kind).resetAt
            else { return false }
            return abs(candidateReset.timeIntervalSince(resetAt)) <= 120
        }.sorted { $0.collectedAt < $1.collectedAt }
        guard let first = matching.first,
              let latest = matching.last,
              first.collectedAt < latest.collectedAt
        else { return nil }

        let usageChange = latest.window(kind).usedPercent - first.window(kind).usedPercent
        let elapsedHours = latest.collectedAt.timeIntervalSince(first.collectedAt) / 3_600
        guard usageChange > 0, elapsedHours > 0 else { return nil }

        let percentPerHour = Double(usageChange) / elapsedHours
        let projectedExhaustionAt = current.collectedAt.addingTimeInterval(
            TimeInterval(Double(currentWindow.remainingPercent) / percentPerHour * 3_600)
        )
        guard projectedExhaustionAt < resetAt else { return nil }
        return QuotaForecast(
            projectedExhaustionAt: projectedExhaustionAt,
            resetAt: resetAt,
            percentPerHour: percentPerHour
        )
    }
}

struct QuotaRecord: Sendable {
    let presentation: QuotaPresentation
    let fiveHourForecast: QuotaForecast?
    let weeklyForecast: QuotaForecast?

    static func withoutForecasts(_ presentation: QuotaPresentation) -> QuotaRecord {
        QuotaRecord(presentation: presentation, fiveHourForecast: nil, weeklyForecast: nil)
    }
}
