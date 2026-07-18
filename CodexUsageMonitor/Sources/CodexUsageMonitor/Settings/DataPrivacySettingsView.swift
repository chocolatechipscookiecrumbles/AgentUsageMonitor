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
