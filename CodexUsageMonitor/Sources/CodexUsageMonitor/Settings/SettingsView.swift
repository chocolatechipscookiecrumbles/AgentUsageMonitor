import SwiftUI

struct SettingsView: View {
    @ObservedObject private var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        TabView(selection: $settings.selectedSettingsTab) {
            GeneralSettingsView(
                settings: settings,
                launchAtLogin: launchAtLogin,
                status: viewModel.settingsStatus,
                displayState: viewModel.displayState
            )
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.systemImage) }
                .tag(SettingsTab.general)

            NotificationSettingsView(
                settings: settings,
                setAlertsEnabled: viewModel.setAlertsEnabled,
                openNotificationSettings: viewModel.openNotificationSettings
            )
            .tabItem { Label(SettingsTab.notifications.title, systemImage: SettingsTab.notifications.systemImage) }
            .tag(SettingsTab.notifications)

            RefreshSettingsView(viewModel: viewModel)
                .tabItem { Label(SettingsTab.refresh.title, systemImage: SettingsTab.refresh.systemImage) }
                .tag(SettingsTab.refresh)

            AgentsSettingsView(viewModel: viewModel)
                .tabItem { Label(SettingsTab.agents.title, systemImage: SettingsTab.agents.systemImage) }
                .tag(SettingsTab.agents)

            DataPrivacySettingsView()
                .tabItem { Label(SettingsTab.dataPrivacy.title, systemImage: SettingsTab.dataPrivacy.systemImage) }
                .tag(SettingsTab.dataPrivacy)

            DiagnosticsSettingsView(status: viewModel.settingsStatus)
                .tabItem { Label(SettingsTab.diagnostics.title, systemImage: SettingsTab.diagnostics.systemImage) }
                .tag(SettingsTab.diagnostics)
        }
        .frame(width: 680, height: 560)
        .preferredColorScheme(settings.appearancePreference.colorScheme)
    }
}
