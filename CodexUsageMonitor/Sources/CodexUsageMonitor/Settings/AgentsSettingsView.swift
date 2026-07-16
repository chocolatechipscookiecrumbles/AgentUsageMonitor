import SwiftUI

struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        SettingsPage {
            CodexAgentSettingsView(
                status: viewModel.settingsStatus,
                connectionState: viewModel.connectionState,
                signInWithBrowser: viewModel.signInWithBrowser,
                signInWithCLI: viewModel.signInWithCLI,
                checkConnection: viewModel.checkCodexConnection
            )

            PlannedAgentSettingsView(agent: .claudeCode)
            PlannedAgentSettingsView(agent: .githubCopilot)
        }
    }
}
