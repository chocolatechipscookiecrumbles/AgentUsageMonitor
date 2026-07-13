import Foundation

struct QuotaWindow: Codable, Equatable, Sendable {
    let usedPercent: Int
    let resetAt: Date?
    let durationMinutes: Int?

    var remainingPercent: Int { max(0, 100 - usedPercent) }
}

enum ConfirmationState: String, Codable, Sendable {
    case confirmed
    case confirmedAfterRetry = "confirmed-after-retry"
    case cachedLastKnownGood = "cached-last-known-good"
    case unconfirmed
    case unavailable

    var displayName: String {
        switch self {
        case .confirmed: "Confirmed"
        case .confirmedAfterRetry: "Confirmed after retry"
        case .cachedLastKnownGood: "Cached last-known-good"
        case .unconfirmed: "Unconfirmed"
        case .unavailable: "Unavailable"
        }
    }

    var isTrusted: Bool {
        self == .confirmed || self == .confirmedAfterRetry || self == .cachedLastKnownGood
    }
}

struct QuotaPresentation: Codable, Equatable, Sendable {
    let accountFingerprint: String?
    let limitID: String?
    let planType: String?
    let creditBalance: String?
    let hasCredits: Bool?
    let availableResetCredits: Int?
    let resetCreditExpiryDates: [Date]
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow?
    let confirmation: ConfirmationState
    let collectedAt: Date
    let source: String
    let detail: String?

    static func unavailable(_ detail: String) -> QuotaPresentation {
        QuotaPresentation(
            accountFingerprint: nil,
            limitID: nil,
            planType: nil,
            creditBalance: nil,
            hasCredits: nil,
            availableResetCredits: nil,
            resetCreditExpiryDates: [],
            fiveHour: nil,
            weekly: nil,
            confirmation: .unavailable,
            collectedAt: .now,
            source: "none",
            detail: detail
        )
    }
}

struct CodexQuotaSample: Sendable {
    let accountFingerprint: String
    let limitID: String
    let planType: String?
    let creditBalance: String?
    let hasCredits: Bool?
    let availableResetCredits: Int?
    let resetCreditExpiryDates: [Date]
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow
    let collectedAt: Date

    func presentation(confirmation: ConfirmationState, source: String, detail: String? = nil) -> QuotaPresentation {
        QuotaPresentation(
            accountFingerprint: accountFingerprint,
            limitID: limitID,
            planType: planType,
            creditBalance: creditBalance,
            hasCredits: hasCredits,
            availableResetCredits: availableResetCredits,
            resetCreditExpiryDates: resetCreditExpiryDates,
            fiveHour: fiveHour,
            weekly: weekly,
            confirmation: confirmation,
            collectedAt: collectedAt,
            source: source,
            detail: detail
        )
    }
}
