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
    let extraUsage: ClaudeExtraUsage?
    let source: ClaudeUsageSource
    let capturedAt: Date
    let schemaVersion: Int
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
    let snapshot: ClaudeUsageSnapshot
    let delivery: ClaudeUsageDelivery
    let warnings: [String]
}
