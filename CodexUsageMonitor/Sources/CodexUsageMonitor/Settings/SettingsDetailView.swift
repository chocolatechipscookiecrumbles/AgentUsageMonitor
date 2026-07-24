import SwiftUI

struct SettingsDetailView: View {
    let selection: SettingsTab
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let selectedSettingsAgent: AgentProvider

    var body: some View {
        switch selection {
        case .general:
            GeneralSettingsView(
                settings: viewModel.settings,
                launchAtLogin: launchAtLogin
            )
        case .notifications:
            NotificationSettingsView(
                settings: viewModel.settings,
                setAlertsEnabled: viewModel.setAlertsEnabled,
                openNotificationSettings: viewModel.openNotificationSettings
            )
        case .refresh:
            RefreshSettingsView(viewModel: viewModel)
        case .agents:
            AgentsSettingsView(
                viewModel: viewModel,
                settings: viewModel.settings,
                selectedAgent: selectedSettingsAgent
            )
        case .dataPrivacy:
            DataPrivacySettingsView()
        case .diagnostics:
            DiagnosticsSettingsView(status: viewModel.settingsStatus)
        }
    }
}
