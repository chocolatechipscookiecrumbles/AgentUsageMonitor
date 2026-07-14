import Foundation

enum RemainingQuotaThreshold: Int, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case fifty = 50
    case twentyFive = 25
    case ten = 10
    case five = 5

    var id: Int { rawValue }
    var title: String { "\(rawValue)% remaining" }
}
