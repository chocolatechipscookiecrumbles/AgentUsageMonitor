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
                    alertsEnabled: viewModel.settings.alertsEnabled,
                    isWarningThresholdEnabled: viewModel.settings.isQuotaThresholdEnabled,
                    setWarningThresholdEnabled: viewModel.settings.setQuotaThreshold,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI,
                    checkConnection: viewModel.checkCodexConnection
                )
            case .claudeCode:
                ClaudeUsageStatusView(
                    state: viewModel.claudeState,
                    signInMethod: .claudeCodeCredentials,
                    refresh: viewModel.refreshClaude,
                    useClaudeCodeCredentials: viewModel.refreshClaude
                )
            case .githubCopilot:
                EmptyView()
            }
        }
    }
}
