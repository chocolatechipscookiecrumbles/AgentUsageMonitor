import SwiftUI

struct AgentsSettingsView: View {
    let status: SettingsStatus

    var body: some View {
        Form {
            Section("Current integration") {
                LabeledContent("Agent", value: "OpenAI Codex")
                LabeledContent("Status", value: status.codexStatus.displayName)
                if let planName = status.planName {
                    LabeledContent("Plan", value: planName)
                }
                LabeledContent("Quota verification", value: status.confirmation.displayName)
                Text("Codex is the only active agent integration in this build.")
                    .foregroundStyle(.secondary)
            }

            Section("Planned agents") {
                LabeledContent("Claude Code", value: "Not connected")
                LabeledContent("GitHub Copilot", value: "Not connected")
                Text("Claude Code and GitHub Copilot are roadmap entries only. Their connection and usage features are not implemented yet.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("The Agents screen never displays an email address, account fingerprint, credential, or authentication token.")
                    .foregroundStyle(.secondary)
            }

            Section("Planned connection flow") {
                Text("Browser sign-in and a visible Codex CLI login option arrive in the Codex Connection phase. Logout and account switching remain out of scope.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
