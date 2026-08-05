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
                VStack(alignment: .leading, spacing: 8) {
                    SettingsDescription(disclosure)
                    Button("Connect \(provider.tabTitle)", action: connect)
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
            "Claude is not connected. Connecting goes through Claude Code and may ask for Keychain access. It lets Agent Monitor read your five-hour and weekly quota, and read Claude Code usage records already on this Mac. Nothing is read until you connect."
        case .githubCopilot:
            "\(provider.title) is not connected."
        }
    }
}
