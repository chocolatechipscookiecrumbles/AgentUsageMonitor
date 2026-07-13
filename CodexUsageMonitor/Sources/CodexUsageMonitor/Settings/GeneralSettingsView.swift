import SwiftUI

struct GeneralSettingsView: View {
    let status: SettingsStatus

    var body: some View {
        Form {
            Section("Application") {
                LabeledContent("Name", value: "Codex Usage Monitor")
                LabeledContent("Version", value: status.appVersion)
                LabeledContent("Build", value: status.buildNumber)
            }

            Section("Current scope") {
                LabeledContent("Provider", value: "OpenAI Codex")
                Text("The daily-driver roadmap remains Codex-first. Additional providers are not active in this build.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
