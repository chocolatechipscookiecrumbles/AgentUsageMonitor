import SwiftUI

struct SettingsPreviewView: View {
    let selection: SettingsTab
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider
    let connectionState: AgentConnectionState
    let settingsStatus: SettingsStatus

    /// Built for every active provider, not just the selected one, so the
    /// rail compares providers instead of restating the current page.
    private var providerSummaries: [ProviderContextSummary] {
        ProviderContextSummary.activeProviders(claudeIsUsable: viewModel.claudeState.isAvailable)
            .compactMap { provider in
                switch provider {
                case .codex:
                    .codex(
                        connectionState: connectionState,
                        presentation: viewModel.presentation,
                        lastConfirmedAt: viewModel.displayState.lastConfirmedAt,
                        valueMode: viewModel.settings.quotaValueMode
                    )
                case .claudeCode:
                    .claude(
                        connectionState: viewModel.claudeConnectionState,
                        usageState: viewModel.claudeState,
                        valueMode: viewModel.settings.quotaValueMode
                    )
                case .githubCopilot:
                    nil
                }
            }
    }

    var body: some View {
        switch selection {
        case .general:
            GeneralSettingsContextView(
                settings: viewModel.settings,
                status: viewModel.settingsStatus,
                displayState: viewModel.displayState
            )
        case .notifications:
            NotificationSettingsContextView(settings: viewModel.settings)
        case .refresh:
            RefreshSettingsContextView(viewModel: viewModel)
        case .agents:
            AgentConnectionsContextView(summaries: providerSummaries)
        case .dataPrivacy:
            StatusSettingsContextView(
                title: "Local and Private",
                summary: "All monitor data stays in the app's local Application Support directory.",
                systemImage: "lock.shield.fill",
                color: .green,
                values: [
                    SettingsContextValue(label: "Directory", value: "Owner only"),
                    SettingsContextValue(label: "Files", value: "Owner only"),
                    SettingsContextValue(label: "Stores", value: LocalDataInventory.stores.count.formatted()),
                ]
            )
        case .diagnostics:
            StatusSettingsContextView(
                title: "Collector Status",
                summary: viewModel.settingsStatus.displayMode.displayName,
                systemImage: viewModel.settingsStatus.displayMode == .confirmedCompleted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                color: viewModel.settingsStatus.displayMode == .confirmedCompleted ? .green : .orange,
                values: [
                    SettingsContextValue(label: "Activity", value: viewModel.settingsStatus.refreshActivity),
                    SettingsContextValue(
                        label: "Last attempt",
                        value: viewModel.settingsStatus.lastAttemptAt.formatted(date: .omitted, time: .shortened)
                    ),
                    SettingsContextValue(
                        label: "Outcomes",
                        value: viewModel.settingsStatus.diagnostics.outcomes.values.reduce(0, +).formatted()
                    ),
                ]
            )
        }
    }
}
