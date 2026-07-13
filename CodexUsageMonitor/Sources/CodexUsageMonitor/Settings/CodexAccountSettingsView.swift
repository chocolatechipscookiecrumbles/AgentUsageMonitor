import SwiftUI

struct CodexAccountSettingsView: View {
    let status: SettingsStatus

    var body: some View {
        Form {
            Section("Detected account") {
                LabeledContent("Status", value: status.accountStatus.displayName)
                if let planName = status.planName {
                    LabeledContent("Plan", value: planName)
                }
                LabeledContent("Quota verification", value: status.confirmation.displayName)
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
