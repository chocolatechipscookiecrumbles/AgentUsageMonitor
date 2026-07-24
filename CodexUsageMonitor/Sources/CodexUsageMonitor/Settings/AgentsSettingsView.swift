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
                    isWarningThresholdEnabled: { viewModel.settings.isQuotaThresholdEnabled($0, for: .codex) },
                    setWarningThresholdEnabled: { viewModel.settings.setQuotaThreshold($0, enabled: $1, for: .codex) },
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI,
                    checkConnection: viewModel.checkCodexConnection
                )
            case .claudeCode:
                ClaudeAgentSettingsView(
                    setupState: viewModel.claudeSetupState,
                    connectionState: viewModel.claudeConnectionState,
                    usageState: viewModel.claudeState,
                    valueMode: viewModel.settings.quotaValueMode,
                    alertsEnabled: viewModel.settings.alertsEnabled,
                    isWarningThresholdEnabled: { viewModel.settings.isQuotaThresholdEnabled($0, for: .claudeCode) },
                    setWarningThresholdEnabled: { viewModel.settings.setQuotaThreshold($0, enabled: $1, for: .claudeCode) },
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
