import SwiftUI

struct CodexAgentSettingsView: View {
    let status: SettingsStatus
    let connectionState: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void
    let checkConnection: () -> Void

    var body: some View {
        Form {
            Section("Current integration") {
                LabeledContent("Agent", value: AgentProvider.codex.title)
                LabeledContent("Status", value: connectionState.displayName)
                if let planName {
                    LabeledContent("Plan", value: planName)
                }
                LabeledContent("Quota status", value: status.displayMode.displayName)
                Text("Codex is the only active agent integration in this build.")
                    .foregroundStyle(.secondary)
            }

            Section("Connection") {
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

            Section("Privacy") {
                Text("Codex owns sign-in and credential storage. This app never displays an email address, account fingerprint, credential, or authentication token.")
                    .foregroundStyle(.secondary)
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
            Text("Checking the Codex connection…")
                .foregroundStyle(.secondary)
        case .missingCLI:
            Text("Install the Codex CLI, then check again. Both sign-in options use the official Codex executable.")
                .foregroundStyle(.secondary)
        case .disconnected:
            Text("Connect Codex to show current five-hour and weekly usage.")
                .foregroundStyle(.secondary)
        case .signingIn(.browser):
            Text("Finish signing in in your browser.")
                .foregroundStyle(.secondary)
        case .signingIn(.cli):
            Text("Finish signing in in the Terminal window.")
                .foregroundStyle(.secondary)
        case .connected:
            Text("Codex is connected. Logout and account switching are not included in this phase.")
                .foregroundStyle(.secondary)
        case .failed(let failure):
            Text(failure.displayMessage)
                .foregroundStyle(.orange)
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
