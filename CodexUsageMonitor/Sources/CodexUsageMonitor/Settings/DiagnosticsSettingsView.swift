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
        Form {
            Section("Latest refresh") {
                LabeledContent("Status", value: status.displayMode.displayName)
                LabeledContent("Last attempt") {
                    Text(status.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastConfirmedAt = status.lastConfirmedAt {
                    LabeledContent("Last confirmed") {
                        Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                LabeledContent("Activity", value: status.refreshActivity)
            }

            Section("Outcomes · last 30 days") {
                if status.diagnostics.outcomes.isEmpty {
                    Text("No recorded outcomes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(outcomeOrder, id: \.rawValue) { outcome in
                        if let count = status.diagnostics.outcomes[outcome] {
                            LabeledContent(outcome.displayName, value: count.formatted())
                        }
                    }
                }
            }

            Section("Classified failures · last 30 days") {
                if status.diagnostics.failureKinds.isEmpty {
                    Text("No classified failures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(status.diagnostics.failureKinds.keys.sorted(), id: \.self) { failureKind in
                        LabeledContent(failureKind, value: status.diagnostics.failureKinds[failureKind, default: 0].formatted())
                    }
                }
                Text("Diagnostics contain stable classifications only, never raw provider error text or quota values.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
