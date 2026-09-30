import SwiftUI

struct SettingsDetailView: View {
    let selection: SettingsTab
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let selectedSettingsAgent: AgentProvider

    var body: some View {
        // Every destination stays mounted; a switch only changes visibility.
        // See `SettingsDestinationStack` for why a `switch` is not used here.
        SettingsDestinationStack(selection: selection) { destination in
            page(for: destination)
        }
        .onChange(of: selection) { _, destination in
            pageDidBecomeVisible(destination)
        }
    }

    @ViewBuilder
    private func page(for destination: SettingsTab) -> some View {
        switch destination {
        case .general:
            GeneralSettingsView(
                viewModel: viewModel,
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
                enrollment: viewModel.enrollment,
                selectedAgent: selectedSettingsAgent
            )
        case .dataPrivacy:
            DataPrivacySettingsView()
        case .diagnostics:
            DiagnosticsSettingsView(
                status: viewModel.settingsStatus,
                clearDiagnostics: viewModel.clearRefreshDiagnostics
            )
        }
    }

    /// Retained pages do not re-run `onAppear` when revisited, so repeat the
    /// refreshes they performed each time they were shown.
    private func pageDidBecomeVisible(_ destination: SettingsTab) {
        switch destination {
        case .general:
            launchAtLogin.refresh()
        case .agents where selectedSettingsAgent == .claudeCode:
            viewModel.refreshClaudePassiveCaptureHealth()
        default:
            break
        }
    }
}
