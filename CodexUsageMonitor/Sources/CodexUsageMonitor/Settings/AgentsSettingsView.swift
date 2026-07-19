import SwiftUI

struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider

    var body: some View {
        SettingsPage {
            switch selectedAgent {
            case .codex:
                CodexAgentSettingsView(
                    status: viewModel.settingsStatus,
                    connectionState: viewModel.connectionState,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI,
                    checkConnection: viewModel.checkCodexConnection
                )
            case .claudeCode:
                ClaudeCodePreviewSettingsView()
            case .githubCopilot:
                EmptyView()
            }
        }
    }
}
