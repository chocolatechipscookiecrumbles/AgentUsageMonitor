import SwiftUI

/// Shared navigation for the provider-specific portion of Agents Settings.
/// The ordinary, fitting layout avoids a scroll gesture competing with tab
/// buttons; a future wider catalog falls back to horizontal overflow here.
struct AgentSettingsTabStrip: View {
    let entries: [AgentSettingsCatalogEntry]
    @Binding var selection: AgentProvider
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabButtons
                .fixedSize(horizontal: true, vertical: false)

            ScrollView(.horizontal, showsIndicators: false) {
                tabButtons
            }
        }
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .onMoveCommand(perform: moveSelection)
    }

    private var tabButtons: some View {
        HStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    ProviderSwitchTrace.record(
                        surface: .settingsAgents,
                        phase: .buttonAction,
                        provider: entry.provider
                    )
                    selection = entry.provider
                } label: {
                    HStack(spacing: SettingsLayoutMetrics.agentHeaderItemSpacing) {
                        AgentSettingsIcon(
                            provider: entry.provider,
                            slotSize: SettingsLayoutMetrics.agentHeaderIconSlotSize,
                            artworkMaxSize: SettingsLayoutMetrics.agentHeaderIconArtworkMaxSize
                        )
                        Text(entry.provider.tabTitle)
                    }
                    .font(.system(size: 14, weight: selection == entry.provider ? .semibold : .regular))
                    .foregroundStyle(selection == entry.provider ? .primary : .secondary)
                    .frame(
                        width: SettingsLayoutMetrics.agentHeaderTabWidth,
                        height: SettingsLayoutMetrics.pageHeaderHeight
                    )
                    .overlay(alignment: .bottom) {
                        if selection == entry.provider {
                            Rectangle()
                                .fill(entry.provider.settingsPresentationTint)
                                .frame(
                                    width: SettingsLayoutMetrics.agentHeaderUnderlineWidth,
                                    height: SettingsLayoutMetrics.agentHeaderUnderlineHeight
                                )
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.provider.title)
                .accessibilityValue(selection == entry.provider ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection == entry.provider ? .isSelected : [])

                if index < entries.index(before: entries.endIndex) {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(
                            width: SettingsLayoutMetrics.dividerWidth,
                            height: SettingsLayoutMetrics.agentHeaderDividerHeight
                        )
                        .accessibilityHidden(true)
                }
            }
        }
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
}
