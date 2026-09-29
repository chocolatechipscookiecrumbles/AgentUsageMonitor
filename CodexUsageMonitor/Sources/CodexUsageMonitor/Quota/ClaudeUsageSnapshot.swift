import Foundation

struct ClaudeLimitWindow: Codable, Sendable, Equatable {
    let usedPercent: Double
    let resetsAt: Date?
}

struct ClaudeScopedLimitWindow: Codable, Sendable, Equatable {
    let identifier: String
    let displayName: String
    let usedPercent: Double
    let resetsAt: Date?
}

struct ClaudeExtraUsage: Codable, Sendable, Equatable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let currencyCode: String?
}

enum ClaudeUsageSource: String, Codable, Sendable, Equatable {
    case oauth
    case statusLine
    /// Tier 2 — a user-initiated read via the Claude Code CLI. Never produced
    /// by an automatic refresh, because it costs tokens.
    case cli
    case cache
}

/// The one normalized representation every source (OAuth, statusLine, cache)
/// produces, so the rest of the app never needs to know which source a
/// result came from to display it.
struct ClaudeUsageSnapshot: Codable, Sendable, Equatable {
    let planHint: String?
    let fiveHour: ClaudeLimitWindow?
    let sevenDay: ClaudeLimitWindow?
    let scopedWindows: [ClaudeScopedLimitWindow]
    var extraUsage: ClaudeExtraUsage?
    let source: ClaudeUsageSource
    let capturedAt: Date
    let schemaVersion: Int
    /// Separate from quota capture time when a quota-only reading retains spending.
    /// Optional for caches written before financial observation times were stored.
    var extraUsageObservedAt: Date? = nil

    var hasQuotaWindows: Bool {
        fiveHour != nil || sevenDay != nil || !scopedWindows.isEmpty
    }

    func retainingExtraUsage(from previous: ClaudeUsageSnapshot?) -> Self {
        guard let previous, previous.extraUsage != nil else { return self }
        if extraUsage != nil,
           (extraUsageObservedAt ?? capturedAt) >= (previous.extraUsageObservedAt ?? previous.capturedAt) {
            return self
        }
        var result = self
        result.extraUsage = previous.extraUsage
        result.extraUsageObservedAt = previous.extraUsageObservedAt ?? previous.capturedAt
        return result
    }
}

enum ClaudeUsageDelivery: Sendable, Equatable {
    case live
    case passiveSnapshot
    case cached
}

/// Wraps a snapshot with how it was delivered, so a result cached from an
/// OAuth read still reports source == .oauth (where the data originated)
/// separately from delivery == .cached (that it's not fresh right now).
struct ClaudeUsagePresentation: Sendable {
    static let passiveFreshness: TimeInterval = 2 * 60

    let snapshot: ClaudeUsageSnapshot
    let delivery: ClaudeUsageDelivery
    let warnings: [String]

    func isFreshPassive(at now: Date) -> Bool {
        guard delivery == .passiveSnapshot, snapshot.source == .statusLine else { return false }
        let age = now.timeIntervalSince(snapshot.capturedAt)
        return (0...Self.passiveFreshness).contains(age)
    }
}
