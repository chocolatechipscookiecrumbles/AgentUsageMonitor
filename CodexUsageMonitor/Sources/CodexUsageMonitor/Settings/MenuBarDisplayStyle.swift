import Foundation

enum MenuBarDisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case gaugeAndLowest = "gauge-and-lowest"
    case fiveHourAndWeekly = "five-hour-and-weekly"
    case stackedBars = "stacked-bars"
    case combinedBars = "combined-bars"

    var id: Self { self }

    var title: String {
        switch self {
        case .gaugeAndLowest: "Gauge"
        case .fiveHourAndWeekly: "5-hour and weekly"
        case .stackedBars: "Bars"
        case .combinedBars: "Combined"
        }
    }

    /// The two graphical modes render provider bars instead of text.
    var isGraphical: Bool {
        switch self {
        case .gaugeAndLowest, .fiveHourAndWeekly: false
        case .stackedBars, .combinedBars: true
        }
    }
}
