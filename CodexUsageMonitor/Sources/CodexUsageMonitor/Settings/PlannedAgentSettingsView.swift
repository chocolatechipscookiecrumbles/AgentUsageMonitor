import SwiftUI

struct PlannedAgentSettingsView: View {
    let agent: AgentProvider

    var body: some View {
        SettingsSection(agent.title) {
            SettingsSectionRow {
                SettingsLabeledRow("Status") { Text("Planned") }
            }
            SettingsSectionRow {
                SettingsLabeledRow("Connection") { Text("Not connected") }
            }
            SettingsSectionRow(showsDivider: false) {
                VStack(alignment: .leading, spacing: 6) {
                    SettingsDescription("This agent is listed for roadmap visibility only. Connection, quota, and usage features are not implemented.")
                    SettingsDescription("No account or usage data is collected for this agent.")
                }
            }
        }
    }
}
