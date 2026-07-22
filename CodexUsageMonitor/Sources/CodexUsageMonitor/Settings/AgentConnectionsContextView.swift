import SwiftUI

/// One status block per active provider, stacked in the context rail — an
/// at-a-glance comparison rather than a description of the selected page.
/// GitHub Copilot is absent until its capability gate passes.
struct AgentConnectionsContextView: View {
    let summaries: [ProviderContextSummary]

    var body: some View {
        ForEach(summaries) { summary in
            ProviderContextCard(summary: summary)
        }
    }
}

/// Renders one provider's block using the existing context primitives.
struct ProviderContextCard: View {
    let summary: ProviderContextSummary

    var body: some View {
        SettingsContextCard(summary.provider.tabTitle) {
            HStack(spacing: SettingsLayoutMetrics.agentHeaderItemSpacing) {
                AgentSettingsIcon(
                    provider: summary.provider,
                    slotSize: SettingsLayoutMetrics.agentContextIconSlotSize,
                    artworkMaxSize: SettingsLayoutMetrics.agentContextIconArtworkMaxSize
                )
                // The provider is named here, not just drawn — an icon alone
                // does not identify the block once several are stacked.
                Text(summary.provider.tabTitle)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(summary.provider.settingsPresentationTint)

            SettingsPaletteDivider()

            SettingsContextValueRow(
                value: SettingsContextValue(label: "Plan", value: summary.planText)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Five-hour", value: summary.fiveHourText)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Weekly", value: summary.weeklyText)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Status", value: summary.statusText)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Last refresh", value: summary.lastRefreshText)
            )
        }
    }
}
