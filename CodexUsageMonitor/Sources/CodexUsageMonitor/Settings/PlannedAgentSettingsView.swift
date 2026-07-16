import SwiftUI

struct PlannedAgentSettingsView: View {
    let agent: AgentProvider

    var body: some View {
        SettingsSection(agent.title) {
            SettingsLabeledRow("Status") { Text("Planned") }
            SettingsLabeledRow("Connection") { Text("Not connected") }
            SettingsDescription("This agent is listed for roadmap visibility only. Connection, quota, and usage features are not implemented.")
            SettingsDescription("No account or usage data is collected for this agent.")
        }
    }
}
