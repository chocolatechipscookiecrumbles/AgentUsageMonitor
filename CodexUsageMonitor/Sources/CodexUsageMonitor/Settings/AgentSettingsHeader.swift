import SwiftUI

struct AgentSettingsHeader: View {
    let entries: [AgentSettingsCatalogEntry]
    @Binding var selection: AgentProvider
    @Binding var isContextRailVisible: Bool
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        HStack(spacing: SettingsLayoutMetrics.pageHeaderContentSpacing) {
            AgentSettingsTabStrip(entries: entries, selection: $selection)
                .layoutPriority(1)

            Spacer(minLength: 0)

            Button(
                isContextRailVisible ? "Hide Context Rail" : "Show Context Rail",
                systemImage: "sidebar.right",
                action: toggleContextRail
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityLabel(isContextRailVisible ? "Hide Context Rail" : "Show Context Rail")
            .accessibilityValue(isContextRailVisible ? "Visible" : "Hidden")
            .help(isContextRailVisible ? "Hide Context Rail" : "Show Context Rail")
        }
        .padding(.trailing, SettingsLayoutMetrics.pageHeaderHorizontalPadding)
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .background(palette.windowBackground)
    }

    private func toggleContextRail() {
        isContextRailVisible.toggle()
    }
}
