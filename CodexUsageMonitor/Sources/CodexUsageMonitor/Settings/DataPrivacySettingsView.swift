import SwiftUI

struct DataPrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Local storage") {
                LabeledContent("Directory", value: LocalDataInventory.directory)
                LabeledContent("Directory permissions", value: "Owner only (0700)")
                LabeledContent("File permissions", value: "Owner only (0600)")
            }

            ForEach(LocalDataInventory.stores) { store in
                Section(store.title) {
                    LabeledContent("File", value: store.fileName)
                    LabeledContent("Retention", value: store.retention)
                    Text(store.contents)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Excluded data") {
                Text("The app does not store passwords, OAuth tokens, email addresses, prompts, source code, raw provider responses, or raw provider errors.")
                    .foregroundStyle(.secondary)
                Text("Export and deletion controls are intentionally deferred.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
