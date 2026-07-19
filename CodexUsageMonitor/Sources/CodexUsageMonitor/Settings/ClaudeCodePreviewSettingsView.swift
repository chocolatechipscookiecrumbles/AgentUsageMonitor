import SwiftUI

struct ClaudeCodePreviewSettingsView: View {
    var body: some View {
        SettingsSection("Claude Code") {
            SettingsSectionRow {
                SettingsLabeledRow("Status") { Text("Not available yet") }
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription("This preview demonstrates the Agents Settings layout only. Claude Code is not connected, and this app does not read its files, credentials, usage, or account data.")
            }
        }

        SettingsSection("Availability") {
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription("A Claude Code integration requires a separate capability and privacy plan before connection, refresh, or notification controls can be offered.")
            }
        }
    }
}
