import SwiftUI

struct DiagnosticsSettingsView: View {
    let status: SettingsStatus

    private let outcomeOrder: [RefreshOutcome] = [
        .confirmed,
        .confirmedAfterRetry,
        .cachedLastKnownGood,
        .unconfirmed,
        .unavailable,
    ]

    var body: some View {
        SettingsPage {
            SettingsSection("Latest refresh") {
                SettingsLabeledRow("Status") { Text(status.displayMode.displayName) }
                SettingsLabeledRow("Last attempt") {
                    Text(status.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastConfirmedAt = status.lastConfirmedAt {
                    SettingsLabeledRow("Last confirmed") {
                        Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                SettingsLabeledRow("Activity") { Text(status.refreshActivity) }
            }

            SettingsSection("Outcomes · last 30 days") {
                if status.diagnostics.outcomes.isEmpty {
                    Text("No recorded outcomes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(outcomeOrder, id: \.rawValue) { outcome in
                        if let count = status.diagnostics.outcomes[outcome] {
                            SettingsLabeledRow(outcome.displayName) { Text(count.formatted()) }
                        }
                    }
                }
            }

            SettingsSection("Classified failures · last 30 days") {
                if status.diagnostics.failureKinds.isEmpty {
                    Text("No classified failures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(status.diagnostics.failureKinds.keys.sorted(), id: \.self) { failureKind in
                        SettingsLabeledRow(failureKind) {
                            Text(status.diagnostics.failureKinds[failureKind, default: 0].formatted())
                        }
                    }
                }
                SettingsDescription("Diagnostics contain stable classifications only, never raw provider error text or quota values.")
            }

            SettingsSection("Application") {
                SettingsLabeledRow("Name") { Text("Codex Usage Monitor") }
                SettingsLabeledRow("Version") { Text(status.appVersion) }
                SettingsLabeledRow("Build") { Text(status.buildNumber) }
            }
        }
    }
}
