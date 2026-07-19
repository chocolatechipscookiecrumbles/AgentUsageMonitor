import SwiftUI

/// Reusable quota/session card for a provider with an available presentation.
/// It deliberately uses only already-sanitized presentation fields.
struct AgentQuotaSessionSection: View {
    let provider: AgentProvider
    let presentation: QuotaPresentation

    var body: some View {
        SettingsSection("Current quota") {
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    title: "5-Hour Window",
                    window: presentation.fiveHour,
                    provider: provider,
                    unavailableText: presentation.weekly == nil ? "Unavailable" : "Not active"
                )
            }
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    title: "Weekly Window",
                    window: presentation.weekly,
                    provider: provider,
                    unavailableText: "Unavailable"
                )
            }
            SettingsSectionRow {
                SettingsLabeledRow("Credits") {
                    Text(presentation.creditBalance ?? "Unavailable")
                        .monospacedDigit()
                }
            }
            SettingsSectionRow(showsDivider: !presentation.resetCreditExpiryDates.isEmpty) {
                SettingsLabeledRow("Banked resets") {
                    Text(presentation.availableResetCredits.map { $0.formatted() } ?? "Unavailable")
                        .monospacedDigit()
                }
            }
            if !presentation.resetCreditExpiryDates.isEmpty {
                SettingsSectionRow(showsDivider: false) {
                    VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                        Text("Reset credit expiry")
                            .foregroundStyle(.secondary)

                        ForEach(presentation.resetCreditExpiryDates, id: \.self) { expiry in
                            Text(expiry, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
