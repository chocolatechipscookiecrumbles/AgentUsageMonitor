import SwiftUI

struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider

    var body: some View {
        AgentSettingsPageTemplate {
            switch selectedAgent {
            case .codex:
                CodexAgentSettingsView(
                    status: viewModel.settingsStatus,
                    connectionState: viewModel.connectionState,
                    presentation: viewModel.presentation,
                    quotaValueMode: viewModel.settings.quotaValueMode,
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
