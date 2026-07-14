import SwiftUI

struct CodexAgentSettingsView: View {
    let status: SettingsStatus
    let connectionState: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void
    let checkConnection: () -> Void

    var body: some View {
        SettingsPage {
            SettingsSection("Current integration") {
                SettingsLabeledRow("Agent") { Text(AgentProvider.codex.title) }
                SettingsLabeledRow("Status") { Text(connectionState.displayName) }
                if let planName {
                    SettingsLabeledRow("Plan") { Text(planName) }
                }
                SettingsLabeledRow("Quota status") { Text(status.displayMode.displayName) }
                SettingsDescription("Codex is the only active agent integration in this build.")
            }

            SettingsSection("Connection") {
                connectionGuidance
                if showsSignInActions {
                    Button("Sign in with browser", action: signInWithBrowser)
                        .disabled(signInDisabled)
                    Button("Sign in with Codex CLI…", action: signInWithCLI)
                        .disabled(signInDisabled)
                }
                if connectionState == .missingCLI {
                    Button("Check again", action: checkConnection)
                }
            }

            SettingsSection("Privacy") {
                SettingsDescription("Codex owns sign-in and credential storage. This app never displays an email address, account fingerprint, credential, or authentication token.")
            }
        }
    }

    private var planName: String? {
        guard case .connected(let account) = connectionState else { return nil }
        return account.planType?.capitalized ?? status.planName
    }

    @ViewBuilder
    private var connectionGuidance: some View {
        switch connectionState {
        case .checking:
            SettingsDescription("Checking the Codex connection…")
        case .missingCLI:
            SettingsDescription("Install the Codex CLI, then check again. Both sign-in options use the official Codex executable.")
        case .disconnected:
            SettingsDescription("Connect Codex to show current five-hour and weekly usage.")
        case .signingIn(.browser):
            SettingsDescription("Finish signing in in your browser.")
        case .signingIn(.cli):
            SettingsDescription("Finish signing in in the Terminal window.")
        case .connected:
            SettingsDescription("Codex is connected. Logout and account switching are not included in this phase.")
        case .failed(let failure):
            Text(failure.displayMessage)
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var showsSignInActions: Bool {
        switch connectionState {
        case .disconnected, .signingIn, .failed:
            true
        case .checking, .missingCLI, .connected:
            false
        }
    }

    private var signInDisabled: Bool {
        if case .signingIn = connectionState { return true }
        return false
    }
}
