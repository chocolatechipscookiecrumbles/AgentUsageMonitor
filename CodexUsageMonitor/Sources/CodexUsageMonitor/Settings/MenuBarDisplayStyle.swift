import Foundation

enum MenuBarDisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case fiveHourAndWeekly = "five-hour-and-weekly"
    case stackedBars = "stacked-bars"
    case combinedBars = "combined-bars"

    var id: Self { self }

    var title: String {
        switch self {
        case .fiveHourAndWeekly: "5-hour and weekly"
        case .stackedBars: "Bars"
        case .combinedBars: "Combined"
        }
    }

    /// The graphical modes render provider bars instead of text.
    var isGraphical: Bool {
        switch self {
        case .fiveHourAndWeekly: false
        case .stackedBars, .combinedBars: true
        }
    }

    /// Whether the style shows a single provider (and therefore needs a provider
    /// choice) rather than every provider at once. The bar modes already show
    /// all providers; the text mode shows one. Any future single-provider icon
    /// style should return `true` here so it inherits the provider selector.
    var isSingleProvider: Bool {
        switch self {
        case .fiveHourAndWeekly: true
        case .stackedBars, .combinedBars: false
        }
    }
}
