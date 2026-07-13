import SwiftUI

struct CodexAgentSettingsView: View {
    let status: SettingsStatus

    var body: some View {
        Form {
            Section("Current integration") {
                LabeledContent("Agent", value: AgentProvider.codex.title)
                LabeledContent("Status", value: status.codexStatus.displayName)
                if let planName = status.planName {
                    LabeledContent("Plan", value: planName)
                }
                LabeledContent("Quota verification", value: status.confirmation.displayName)
                Text("Codex is the only active agent integration in this build.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("This screen never displays an email address, account fingerprint, credential, or authentication token.")
                    .foregroundStyle(.secondary)
            }

            Section("Planned connection flow") {
                Text("Browser sign-in and a visible Codex CLI login option arrive in the Codex Connection phase. Logout and account switching remain out of scope.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
