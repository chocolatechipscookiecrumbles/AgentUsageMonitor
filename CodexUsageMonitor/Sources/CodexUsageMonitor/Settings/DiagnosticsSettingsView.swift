import SwiftUI

struct DiagnosticsSettingsView: View {
    let status: SettingsStatus
    let clearDiagnostics: () -> Void

    @State private var isConfirmingClear = false
    @State private var hasCopiedReport = false

    private static let diagnosticsFileName = "refresh-diagnostics.json"

    var body: some View {
        SettingsPage {
            SettingsSection("Latest refresh") {
                SettingsSectionRow {
                    SettingsLabeledRow("Status") { Text(status.displayMode.displayName) }
                }
                SettingsSectionRow {
                    SettingsLabeledRow("Last attempt") {
                        Text(status.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                if let lastConfirmedAt = status.lastConfirmedAt {
                    SettingsSectionRow {
                        SettingsLabeledRow("Last confirmed") {
                            Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsLabeledRow("Activity") { Text(status.refreshActivity) }
                }
            }

            SettingsSection("Outcomes · last 30 days") {
                SettingsSectionRow(showsDivider: false) {
                    if status.diagnostics.outcomes.isEmpty {
                        Text("No recorded outcomes")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: SettingsLayoutMetrics.sectionRowVerticalPadding) {
                            ForEach(SettingsStatus.outcomeOrder, id: \.rawValue) { outcome in
                                if let count = status.diagnostics.outcomes[outcome] {
                                    SettingsLabeledRow(outcome.displayName) { Text(count.formatted()) }
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection("Classified failures · last 30 days") {
                SettingsSectionRow {
                    if status.diagnostics.failureKinds.isEmpty {
                        Text("No classified failures")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: SettingsLayoutMetrics.sectionRowVerticalPadding) {
                            ForEach(status.diagnostics.failureKinds.keys.sorted(), id: \.self) { failureKind in
                                SettingsLabeledRow(failureKind) {
                                    Text(status.diagnostics.failureKinds[failureKind, default: 0].formatted())
                                }
                            }
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("Diagnostics contain stable classifications only, never raw provider error text or quota values.")
                }
            }

            SettingsSection("Actions") {
                SettingsSectionRow {
                    VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                        HStack(spacing: SettingsLayoutMetrics.rowSpacing) {
                            Button("Copy Report", action: copyReport)
                            Button("Reveal in Finder") {
                                LocalDataActions.revealFile(named: Self.diagnosticsFileName)
                            }
                        }
                        if hasCopiedReport {
                            Text("Copied everything shown on this page.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                        Button("Clear History…") { isConfirmingClear = true }
                        SettingsDescription("Removes the recorded outcomes and classified failures. Quota readings and the refresh schedule are unaffected, and the next refresh starts a new history.")
                    }
                }
            }

            SettingsSection("Application") {
                SettingsSectionRow {
                    SettingsLabeledRow("Name") { Text("Codex Usage Monitor") }
                }
                SettingsSectionRow {
                    SettingsLabeledRow("Version") { Text(status.appVersion) }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsLabeledRow("Build") { Text(status.buildNumber) }
                }
            }
        }
        .confirmationDialog(
            "Clear the recorded refresh history?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                clearDiagnostics()
                hasCopiedReport = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes \(Self.diagnosticsFileName) — up to 30 days of outcomes and classified failures. This cannot be undone.")
        }
    }

    private func copyReport() {
        LocalDataActions.copyToPasteboard(status.diagnosticsReport())
        hasCopiedReport = true
    }
}
