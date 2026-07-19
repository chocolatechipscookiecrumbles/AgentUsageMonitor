import SwiftUI

struct CodexAgentSettingsView: View {
    let status: SettingsStatus
    let connectionState: AgentConnectionState
    let presentation: QuotaPresentation
    let quotaValueMode: QuotaValueMode
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void
    let checkConnection: () -> Void

    var body: some View {
        SettingsSection("Connection") {
            SettingsSectionRow {
                SettingsPreferenceControlRow("Status") { Text(connectionState.displayName) }
            }
            if let planName {
                SettingsSectionRow {
                    SettingsPreferenceControlRow("Plan") { Text(planName) }
                }
            }
            SettingsSectionRow(showsDivider: false) {
                VStack(alignment: .leading, spacing: 8) {
                    connectionGuidance
                    connectionActions
                }
            }
        }

        AgentQuotaSessionSection(
            provider: .codex,
            presentation: presentation,
            valueMode: quotaValueMode
        )

        SettingsSection("Privacy") {
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription("Codex owns sign-in and credential storage. This app never displays an email address, account fingerprint, credential, or authentication token.")
            }
        }
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

    private var planName: String? {
        guard case .connected(let account) = connectionState else { return nil }
        return account.planType?.capitalized ?? status.planName
    }

    @ViewBuilder
    private var connectionActions: some View {
        if showsSignInActions {
            Button("Connect with browser", action: signInWithBrowser)
                .disabled(signInDisabled)
            Button("Connect with Codex CLI…", action: signInWithCLI)
                .disabled(signInDisabled)
        }
        if connectionState == .missingCLI {
            Button("Check again", action: checkConnection)
        }
        if case .connected = connectionState {
            Button("Disconnect") {}
                .disabled(true)
            SettingsDescription("Disconnect is planned. It does not yet change this app or your Codex CLI session.")
        }
    }

    private var signInDisabled: Bool {
        if case .signingIn = connectionState { return true }
        return false
    }
}
