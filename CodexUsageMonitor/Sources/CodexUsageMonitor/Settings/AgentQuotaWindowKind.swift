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
        provider.settingsPresentationTint
    }

    var progressOpacity: CGFloat {
        switch self {
        case .fiveHour:
            1
        case .weekly:
            0.72
        }
    }
}
