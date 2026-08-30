import SwiftUI

/// What an agent's Settings page shows before that provider has been enrolled.
///
/// It mirrors the menu's connect-only tab rather than reusing the operational
/// page with empty values: showing Status, Plan, quota, Token Monitor, and
/// warning controls for a provider the app has never been asked to read would
/// present stale or invented state as though a connection existed.
struct AgentConnectSettingsView: View {
    let provider: AgentProvider
    let connect: () -> Void

    var body: some View {
        SettingsSection("Connection") {
            SettingsSectionRow {
                SettingsPreferenceControlRow("Status") { Text("Not connected") }
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsPreferenceControlRow(
                    "\(provider.tabTitle) connection",
                    description: disclosure
                ) {
                    Button(connectActionTitle, action: connect)
                }
            }
        }
    }

    /// Says what connecting will actually do, including the Keychain prompt on
    /// Claude's path. Nothing here runs until the button is pressed.
    private var disclosure: String {
        switch provider {
        case .codex:
            "Codex is not connected. Connecting lets Agent Monitor read your five-hour and weekly quota, and read Codex usage records already on this Mac. Nothing is read until you connect."
        case .claudeCode:
            ClaudeConnectionCopy.connectionDisclosure
        case .githubCopilot:
            "\(provider.title) is not connected."
        }
    }

    private var connectActionTitle: String {
        provider == .claudeCode ? "Connect Claude" : "Connect \(provider.tabTitle)"
    }
}
