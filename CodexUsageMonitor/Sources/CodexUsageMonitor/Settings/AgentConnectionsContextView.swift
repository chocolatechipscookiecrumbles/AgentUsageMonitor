import SwiftUI

struct AgentConnectionsContextView: View {
    let provider: AgentProvider
    let connectionState: AgentConnectionState
    let status: SettingsStatus

    var body: some View {
        switch provider {
        case .codex:
            codexCard
        case .claudeCode:
            claudeCodePreviewCard
        case .githubCopilot:
            EmptyView()
        }
    }

    private var codexCard: some View {
        SettingsContextCard("Agent Status") {
            Label(connectionState.displayName, systemImage: provider.systemImage)
                .foregroundStyle(SettingsTab.agents.navigationTint)

            SettingsPaletteDivider()

            SettingsContextValueRow(
                value: SettingsContextValue(label: "Current", value: provider.title)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Plan", value: planValue)
            )
            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Quota status",
                    value: status.displayMode.displayName
                )
            )
        }
    }

    private var claudeCodePreviewCard: some View {
        SettingsContextCard("Agent Status") {
            Label("Preview", systemImage: provider.systemImage)
                .foregroundStyle(SettingsTab.agents.navigationTint)

            SettingsPaletteDivider()

            SettingsContextValueRow(
                value: SettingsContextValue(label: "Status", value: "Preview")
            )
            SettingsContextValueRow(
                value: SettingsContextValue(label: "Availability", value: "Not available yet")
            )

            SettingsPaletteDivider()

            SettingsDescription(
                "This preview demonstrates the Agents Settings layout only. Claude Code is not connected, and this app does not read its files, credentials, usage, or account data."
            )
        }
    }

    private var planValue: String {
        guard case .connected(let account) = connectionState else { return "Unavailable" }
        return account.planType?.capitalized ?? status.planName ?? "Unavailable"
    }
}
