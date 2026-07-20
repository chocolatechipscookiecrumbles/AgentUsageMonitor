import Foundation

enum ClaudeUsageState: Equatable, Sendable {
    case notAvailable
    case available(ClaudeRateLimitSnapshot)
}
