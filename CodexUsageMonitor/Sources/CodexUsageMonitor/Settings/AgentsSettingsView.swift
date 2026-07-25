import SwiftUI

struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    // Observed here (not only in the leaf chip view) because
    // `AgentSettingsPageTemplate` captures its content once, freezing the
    // subtree; rebuilding this container is what actually refreshes the chips.
    @ObservedObject var settings: AppSettings
    let selectedAgent: AgentProvider

    var body: some View {
        AgentSettingsPageTemplate {
            switch selectedAgent {
            case .codex:
                CodexAgentSettingsView(
                    settings: viewModel.settings,
                    status: viewModel.settingsStatus,
                    connectionState: viewModel.connectionState,
                    presentation: viewModel.presentation,
                    quotaValueMode: viewModel.settings.quotaValueMode,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI,
                    checkConnection: viewModel.checkCodexConnection,
                    disconnect: viewModel.disconnectCodex
                )
            case .claudeCode:
                ClaudeAgentSettingsView(
                    settings: viewModel.settings,
                    setupState: viewModel.claudeSetupState,
                    connectionState: viewModel.claudeConnectionState,
                    usageState: viewModel.claudeState,
                    valueMode: viewModel.settings.quotaValueMode,
                    connectWithCredentials: viewModel.connectClaudeWithCredentials,
                    disconnect: viewModel.disconnectClaude,
                    refresh: viewModel.refreshClaude,
                    isRunningCLIProbe: viewModel.isRunningClaudeCLIProbe,
                    cliProbeError: viewModel.claudeCLIProbeError,
                    hasConsentedToCLIProbe: viewModel.settings.claudeCLIProbeConsented,
                    setCLIProbeConsent: { viewModel.settings.claudeCLIProbeConsented = $0 },
                    runCLIProbe: viewModel.runClaudeCLIProbe
                )
            case .githubCopilot:
                EmptyView()
            }
        }
    }
}
