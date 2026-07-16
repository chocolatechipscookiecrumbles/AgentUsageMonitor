import SwiftUI

struct SettingsPreviewView: View {
    let selection: SettingsTab
    @ObservedObject var viewModel: QuotaViewModel

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
            StatusSettingsContextView(
                title: "Agent Status",
                summary: viewModel.connectionState.displayName,
                systemImage: "person.2.fill",
                color: .blue,
                values: [
                    SettingsContextValue(label: "Current", value: AgentProvider.codex.title),
                    SettingsContextValue(label: "Planned", value: "2 integrations"),
                ]
            )
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
