import Foundation

enum RefreshReason: String, Codable, Sendable {
    case launch
    case scheduled
    case wake
    case manual
}

enum RefreshState: Equatable, Sendable {
    case idle
    case refreshing(reason: RefreshReason)
    case failed(at: Date)
}
