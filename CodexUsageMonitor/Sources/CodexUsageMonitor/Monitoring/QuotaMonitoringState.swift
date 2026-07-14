import Foundation

enum RefreshReason: String, Codable, Sendable {
    case launch
    case scheduled
    case wake
    case manual
    case authentication
}

enum RefreshState: Equatable, Sendable {
    case idle
    case refreshing(reason: RefreshReason)
    case failed(at: Date)
}

enum QuotaDisplayMode: String, Codable, Sendable {
    case confirmedCompleted = "confirmed-completed"
    case cachedPaused = "cached-paused"

    var displayName: String {
        switch self {
        case .confirmedCompleted: "Confirmed / completed"
        case .cachedPaused: "Cached / paused"
        }
    }
}

enum QuotaPauseReason: String, Codable, Sendable {
    case cachedLastKnownGood = "cached-last-known-good"
    case unconfirmed
    case unavailable
    case repeatedFailures = "repeated-failures"

    var displayName: String {
        switch self {
        case .cachedLastKnownGood: "The latest attempt used the last confirmed result."
        case .unconfirmed: "The latest live samples could not be confirmed."
        case .unavailable: "The latest attempt did not return quota data."
        case .repeatedFailures: "Using the last confirmed result after repeated unsuccessful attempts."
        }
    }
}

struct QuotaDisplayState: Sendable {
    let mode: QuotaDisplayMode
    let displayedRecord: QuotaRecord?
    let lastAttemptAt: Date
    let lastConfirmedAt: Date?
    let pauseReason: QuotaPauseReason?
}
