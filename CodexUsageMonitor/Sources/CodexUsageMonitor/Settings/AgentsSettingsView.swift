import SwiftUI

struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    @State private var selectedAgent: AgentProvider? = .codex

    var body: some View {
        NavigationSplitView {
            List(AgentProvider.allCases, selection: $selectedAgent) { agent in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.title)
                        Text(agent.sidebarStatus(connectionState: viewModel.connectionState))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: agent.systemImage)
                }
                .tag(agent)
            }
            .navigationTitle("Agents")
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 210)
        } detail: {
            if let selectedAgent {
                Group {
                    switch selectedAgent {
                    case .codex:
                        CodexAgentSettingsView(
                            status: viewModel.settingsStatus,
                            connectionState: viewModel.connectionState,
                            signInWithBrowser: viewModel.signInWithBrowser,
                            signInWithCLI: viewModel.signInWithCLI,
                            checkConnection: viewModel.checkCodexConnection
                        )
                    case .claudeCode, .githubCopilot:
                        PlannedAgentSettingsView(agent: selectedAgent)
                    }
                }
                    .navigationTitle(selectedAgent.title)
            } else {
                ContentUnavailableView(
                    "Select an agent",
                    systemImage: "person.3",
                    description: Text("Choose an agent from the sidebar to view its status.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
