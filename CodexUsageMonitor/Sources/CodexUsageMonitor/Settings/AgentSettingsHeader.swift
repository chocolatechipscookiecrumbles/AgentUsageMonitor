import SwiftUI

struct AgentSettingsHeader: View {
    let entries: [AgentSettingsCatalogEntry]
    @Binding var selection: AgentProvider
    @Binding var isContextRailVisible: Bool
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        HStack(spacing: SettingsLayoutMetrics.pageHeaderContentSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(entries) { entry in
                        Button {
                            selection = entry.provider
                        } label: {
                            HStack(spacing: SettingsLayoutMetrics.agentHeaderItemSpacing) {
                                AgentSettingsIcon(
                                    provider: entry.provider,
                                    slotSize: SettingsLayoutMetrics.agentHeaderIconSlotSize,
                                    artworkMaxSize: SettingsLayoutMetrics.agentHeaderIconArtworkMaxSize
                                )
                                Text(entry.provider.title)
                            }
                            .font(.system(size: 14, weight: selection == entry.provider ? .semibold : .regular))
                            .foregroundStyle(selection == entry.provider ? .primary : .secondary)
                            .padding(.horizontal, SettingsLayoutMetrics.agentHeaderItemHorizontalPadding)
                            .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
                            .overlay(alignment: .bottom) {
                                if selection == entry.provider {
                                    Rectangle()
                                        .fill(entry.provider.settingsPresentationTint)
                                        .frame(height: SettingsLayoutMetrics.agentHeaderUnderlineHeight)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.provider.title)
                        .accessibilityValue(selection == entry.provider ? "Selected" : "Not selected")
                        .accessibilityAddTraits(selection == entry.provider ? .isSelected : [])
                    }
                }
            }
            .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
            .onMoveCommand(perform: moveSelection)

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
        .padding(.horizontal, SettingsLayoutMetrics.pageHeaderHorizontalPadding)
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .background(palette.windowBackground)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard let currentIndex = entries.firstIndex(where: { $0.provider == selection }) else {
            selection = entries.first?.provider ?? selection
            return
        }

        switch direction {
        case .left where currentIndex > entries.startIndex:
            selection = entries[entries.index(before: currentIndex)].provider
        case .right where currentIndex < entries.index(before: entries.endIndex):
            selection = entries[entries.index(after: currentIndex)].provider
        default:
            break
        }
    }

    private func toggleContextRail() {
        isContextRailVisible.toggle()
    }
}
