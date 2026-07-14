import SwiftUI

struct DataPrivacySettingsView: View {
    var body: some View {
        SettingsPage {
            SettingsSection("Local storage") {
                SettingsLabeledRow("Directory") {
                    Text(LocalDataInventory.directory)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SettingsLabeledRow("Directory permissions") { Text("Owner only (0700)") }
                SettingsLabeledRow("File permissions") { Text("Owner only (0600)") }
            }

            ForEach(LocalDataInventory.stores) { store in
                SettingsSection(store.title) {
                    SettingsLabeledRow("File") { Text(store.fileName) }
                    SettingsLabeledRow("Retention") {
                        Text(store.retention)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SettingsDescription(store.contents)
                }
            }

            SettingsSection("Excluded data") {
                SettingsDescription("The app does not store passwords, OAuth tokens, email addresses, prompts, source code, raw provider responses, or raw provider errors.")
                SettingsDescription("Export and deletion controls are intentionally deferred.")
            }
        }
    }
}
