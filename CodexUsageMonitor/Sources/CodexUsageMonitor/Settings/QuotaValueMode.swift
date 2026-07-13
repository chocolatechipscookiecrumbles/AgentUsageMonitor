import Foundation

enum QuotaValueMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case remaining
    case used

    var id: Self { self }

    var title: String {
        switch self {
        case .remaining: "Remaining"
        case .used: "Used"
        }
    }

    var accessibilityName: String {
        title.lowercased()
    }

    func value(for window: QuotaWindow) -> Int {
        let value = switch self {
        case .remaining: window.remainingPercent
        case .used: window.usedPercent
        }
        return min(max(value, 0), 100)
    }
}
