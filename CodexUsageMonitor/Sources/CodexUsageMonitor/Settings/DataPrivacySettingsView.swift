import SwiftUI

struct DataPrivacySettingsView: View {
    @State private var exportError: String?
    @State private var exportedFileName: String?

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
                SettingsSectionRow {
                    SettingsLabeledRow("File permissions") { Text("Owner only (0600)") }
                }
                SettingsSectionRow(showsDivider: false) {
                    HStack(spacing: SettingsLayoutMetrics.rowSpacing) {
                        Button("Reveal in Finder", action: LocalDataActions.revealInFinder)
                        Button("Copy Path", action: LocalDataActions.copyDirectoryPath)
                    }
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
                        "Conversation content",
                        value: "Never collected",
                        description: "Quota collection reads only percentages, reset times, and plan type."
                    )
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription(ClaudeUsageDisplayModel.weeklyScopeCaveat)
                }
            }

            // The Token Monitor reads files the agents own, automatically and
            // without asking, so the exact boundary belongs in Settings rather
            // than only in the plan.
            SettingsSection("Token Monitor") {
                SettingsSectionRow {
                    SettingsValueRow(
                        "Local records",
                        value: "Read automatically",
                        description: "For each agent whose Token Monitor is shown, this app reads the session records that agent already writes on this Mac, so the menu can show tokens observed today. This starts on its own, keeps working when an agent is disconnected, makes no network request, and costs no tokens. Turning an agent's Token Monitor off in Agents stops reading that agent's records and removes what was cached for it."
                    )
                }
                SettingsSectionRow {
                    SettingsValueRow(
                        "What is read",
                        value: "Timestamps, models, tokens",
                        description: "Only timestamps, model identifiers, token counts, and opaque identifiers needed to avoid counting the same request twice. Prompts, responses, reasoning, tool activity, file paths, and project names are never decoded."
                    )
                }
                SettingsSectionRow {
                    SettingsValueRow(
                        "Where it is kept",
                        value: "Cached on this Mac",
                        description: "Recent totals are cached in this app's own folder so the menu can show them immediately at the next launch instead of rebuilding first. Only the figures shown on the card are cached — never file paths, agent session identifiers, or record contents. The records themselves stay owned by the agents and are never modified."
                    )
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("These totals describe what this Mac observed, not an account. Records that cannot be read safely are reported as unavailable rather than counted as zero.")
                }
            }

            SettingsSection("Excluded data") {
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("The app does not store passwords, OAuth tokens, email addresses, prompts, source code, raw provider responses, or raw provider errors.")
                }
            }

            SettingsSection("Export") {
                SettingsSectionRow {
                    SettingsDescription("Writes every store listed above to one JSON file you choose. A store this Mac has not written yet is named and marked unavailable rather than left out. Nothing outside this app's own folder is included — not Claude Code's Keychain item, and not the agents' own records.")
                }
                SettingsSectionRow {
                    VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                        Button("Export Local Data…", action: exportLocalData)
                        if let exportedFileName {
                            Text("Exported to \(exportedFileName).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        if let exportError {
                            Text(exportError)
                                .font(.callout)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("The exported file leaves this app's owner-only folder. It is protected by wherever you save it. Deletion controls remain deferred; remove the files in Finder to clear this data today.")
                }
            }
        }
    }

    private func exportLocalData() {
        exportError = nil
        exportedFileName = nil
        do {
            guard let url = try LocalDataActions.runExportPanel() else { return }
            exportedFileName = url.lastPathComponent
        } catch {
            exportError = "Could not write the export: \(error.localizedDescription)"
        }
    }
}
