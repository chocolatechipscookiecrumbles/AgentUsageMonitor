import Foundation

/// One toggleable region of the Token Monitor card, in rendering order.
///
/// The card's header — its title, `This Mac · observed`, the day's total, and
/// the request count — is deliberately absent here. A card that cannot say
/// what it is and what it observed is not worth rendering at all.
enum TokenMonitorSection: String, CaseIterable, Identifiable, Sendable {
    case activityChart
    case tokenCategories
    case modelUsage
    case lastRequest

    var id: Self { self }

    var title: String {
        switch self {
        case .activityChart: "Activity chart"
        case .tokenCategories: "Token categories"
        case .modelUsage: "Model usage"
        case .lastRequest: "Last request"
        }
    }

    /// Deliberately range-neutral: the same rows describe 30-minute bars in the
    /// day view and one bar per day in the week view, so naming either window
    /// here would be wrong half the time.
    var settingsDescription: String {
        switch self {
        case .activityChart:
            "The bars for each interval elapsed in the selected range."
        case .tokenCategories:
            "The range's totals for each token category this agent reports."
        case .modelUsage:
            "The largest model groups and their share of the range's tokens."
        case .lastRequest:
            "The most recent request observed on this Mac, with its model."
        }
    }
}
