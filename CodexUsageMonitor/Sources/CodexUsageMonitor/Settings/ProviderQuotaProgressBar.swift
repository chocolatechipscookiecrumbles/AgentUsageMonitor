import SwiftUI

/// A fixed-geometry provider quota bar whose foreground is the exact provider
/// tint, rather than a native control style that can darken it by appearance.
struct ProviderQuotaProgressBar: View {
    let value: Int
    let provider: AgentProvider

    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.divider)

                Capsule()
                    .fill(provider.settingsPresentationTint)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: SettingsLayoutMetrics.agentQuotaProgressBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.title) quota")
        .accessibilityValue("\(value) percent")
    }

    private var progress: CGFloat {
        CGFloat(min(max(value, 0), 100)) / 100
    }
}
