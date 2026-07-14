import SwiftUI

struct PlannedAgentSettingsView: View {
    let agent: AgentProvider

    var body: some View {
        SettingsPage {
            SettingsSection("Integration status") {
                SettingsLabeledRow("Agent") { Text(agent.title) }
                SettingsLabeledRow("Status") { Text("Planned") }
                SettingsLabeledRow("Connection") { Text("Not connected") }
            }

            SettingsSection("Availability") {
                SettingsDescription("This agent is listed for roadmap visibility only. Connection, quota, and usage features are not implemented.")
                SettingsDescription("OpenAI Codex remains the only active integration in this build.")
            }

            SettingsSection("Privacy") {
                SettingsDescription("No account or usage data is collected for this agent.")
            }
        }
    }
}
