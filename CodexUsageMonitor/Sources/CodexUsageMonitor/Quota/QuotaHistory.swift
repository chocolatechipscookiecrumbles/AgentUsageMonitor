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
    let confidence: ForecastConfidence
    let observationCount: Int

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
        guard let first = matching.first, let latest = matching.last, matching.count >= 3 else { return nil }
        let span = latest.collectedAt.timeIntervalSince(first.collectedAt)
        guard span >= 15 * 60 else { return nil }
        let slopes = zip(matching, matching.dropFirst()).compactMap { older, newer -> Double? in
            let hours = newer.collectedAt.timeIntervalSince(older.collectedAt) / 3_600
            let change = newer.window(kind).usedPercent - older.window(kind).usedPercent
            guard hours > 0, change > 0 else { return nil }
            return Double(change) / hours
        }.sorted()
        guard slopes.count == matching.count - 1 else { return nil }
        let middle = slopes.count / 2
        let percentPerHour = slopes.count.isMultiple(of: 2)
            ? (slopes[middle - 1] + slopes[middle]) / 2
            : slopes[middle]
        let projectedExhaustionAt = current.collectedAt.addingTimeInterval(
            TimeInterval(Double(currentWindow.remainingPercent) / percentPerHour * 3_600)
        )
        guard projectedExhaustionAt < resetAt else { return nil }
        return QuotaForecast(
            projectedExhaustionAt: projectedExhaustionAt,
            resetAt: resetAt,
            percentPerHour: percentPerHour,
            confidence: ForecastConfidence.calculate(observationCount: matching.count, span: span),
            observationCount: matching.count
        )
    }
}

enum ForecastConfidence: String, Codable, Sendable {
    case low
    case medium
    case high

    static func calculate(observationCount: Int, span: TimeInterval) -> ForecastConfidence {
        if observationCount >= 8, span >= 3 * 3_600 { return .high }
        if observationCount >= 5, span >= 3_600 { return .medium }
        return .low
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
