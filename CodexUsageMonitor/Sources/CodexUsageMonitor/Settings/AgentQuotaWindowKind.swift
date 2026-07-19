import SwiftUI

/// Shared visual treatment for the two distinct provider quota horizons.
enum AgentQuotaWindowKind {
    case fiveHour
    case weekly

    var title: String {
        switch self {
        case .fiveHour: "5-Hour Window"
        case .weekly: "Weekly Window"
        }
    }

    func progressTint(for provider: AgentProvider) -> Color {
        switch self {
        case .fiveHour:
            provider.settingsPresentationTint
        case .weekly:
            Color(red: 1, green: 175 / 255, blue: 12 / 255)
        }
    }
}
