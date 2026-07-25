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
        value(forUsedPercent: window.usedPercent)
    }

    /// Transforms a raw *used* percentage into the displayed value for this
    /// mode. Lets non-`QuotaWindow` sources (e.g. Claude's display model) share
    /// the same used/remaining convention.
    func value(forUsedPercent usedPercent: Int) -> Int {
        let value = switch self {
        case .remaining: 100 - usedPercent
        case .used: usedPercent
        }
        return min(max(value, 0), 100)
    }
}
