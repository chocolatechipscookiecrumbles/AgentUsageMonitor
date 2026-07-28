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

    var settingsDescription: String {
        switch self {
        case .activityChart:
            "The 30-minute bars from midnight through the current interval."
        case .tokenCategories:
            "Today's totals for each token category this agent reports."
        case .modelUsage:
            "The largest model groups and their share of today's tokens."
        case .lastRequest:
            "The most recent request observed on this Mac, with its model."
        }
    }
}
