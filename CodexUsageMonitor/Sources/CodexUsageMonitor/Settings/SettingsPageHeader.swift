import SwiftUI

struct SettingsPageHeader: View {
    let selection: SettingsTab
    let entries: [AgentSettingsCatalogEntry]
    @Binding var selectedAgent: AgentProvider
    @Binding var isPreviewVisible: Bool
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        if selection == .agents {
            AgentSettingsHeader(
                entries: entries,
                selection: $selectedAgent,
                isContextRailVisible: $isPreviewVisible
            )
        } else {
            standardTitleHeader
        }
    }

    private var standardTitleHeader: some View {
        HStack(spacing: SettingsLayoutMetrics.pageHeaderContentSpacing) {
            Text(selection.title)
                .font(.system(size: 17, weight: .semibold))

            Spacer(minLength: 0)

            Button(
                isPreviewVisible ? "Hide Context Rail" : "Show Context Rail",
                systemImage: "sidebar.right",
                action: togglePreview
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityLabel(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
            .accessibilityValue(isPreviewVisible ? "Visible" : "Hidden")
            .help(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
        }
        .padding(.horizontal, SettingsLayoutMetrics.pageHeaderHorizontalPadding)
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .background(palette.windowBackground)
    }

    private func togglePreview() {
        isPreviewVisible.toggle()
    }
}
