import Foundation

enum MenuBarDisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case gaugeAndLowest = "gauge-and-lowest"
    case fiveHourAndWeekly = "five-hour-and-weekly"

    var id: Self { self }

    var title: String {
        switch self {
        case .gaugeAndLowest: "Gauge"
        case .fiveHourAndWeekly: "5-hour and weekly"
        }
    }
}
