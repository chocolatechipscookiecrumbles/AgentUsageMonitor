import SwiftUI

struct PlannedAgentSettingsView: View {
    let agent: AgentProvider

    var body: some View {
        Form {
            Section("Integration status") {
                LabeledContent("Agent", value: agent.title)
                LabeledContent("Status", value: "Planned")
                LabeledContent("Connection", value: "Not connected")
            }

            Section("Availability") {
                Text("This agent is listed for roadmap visibility only. Connection, quota, and usage features are not implemented.")
                    .foregroundStyle(.secondary)
                Text("OpenAI Codex remains the only active integration in this build.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("No account or usage data is collected for this agent.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
