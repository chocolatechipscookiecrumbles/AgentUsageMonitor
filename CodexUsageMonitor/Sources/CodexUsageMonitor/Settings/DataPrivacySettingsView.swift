import SwiftUI

struct DataPrivacySettingsView: View {
    var body: some View {
        SettingsPage {
            SettingsSection("Local storage") {
                SettingsSectionRow {
                    SettingsLabeledRow("Directory") {
                        Text(LocalDataInventory.directory)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                SettingsSectionRow {
                    SettingsLabeledRow("Directory permissions") { Text("Owner only (0700)") }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsLabeledRow("File permissions") { Text("Owner only (0600)") }
                }
            }

            ForEach(LocalDataInventory.stores) { store in
                SettingsSection(store.title) {
                    SettingsSectionRow {
                        SettingsLabeledRow("File") { Text(store.fileName) }
                    }
                    SettingsSectionRow {
                        SettingsLabeledRow("Retention") {
                            Text(store.retention)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    SettingsSectionRow(showsDivider: false) {
                        SettingsDescription(store.contents)
                    }
                }
            }

            // Claude reads data this app does not own — a Keychain item and a
            // file another program writes — so what is read, and what is
            // deliberately not, is stated here rather than on the Agents page.
            SettingsSection("Claude Code") {
                SettingsSectionRow {
                    SettingsValueRow(
                        "Credentials",
                        value: "Read, never stored",
                        description: "Claude Code's own Keychain item is read at refresh time. This app keeps no copy of it and never requests a token of its own."
                    )
                }
                SettingsSectionRow {
                    SettingsValueRow(
                        "Conversations",
                        value: "Never read",
                        description: "Only quota percentages, reset times, and plan type are collected."
                    )
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription(ClaudeUsageDisplayModel.weeklyScopeCaveat)
                }
            }

            SettingsSection("Excluded data") {
                SettingsSectionRow {
                    SettingsDescription("The app does not store passwords, OAuth tokens, email addresses, prompts, source code, raw provider responses, or raw provider errors.")
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("Export and deletion controls are intentionally deferred.")
                }
            }
        }
    }
}
