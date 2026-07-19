import SwiftUI

/// Reusable quota/session card for a provider with an available presentation.
/// It deliberately uses only already-sanitized presentation fields.
struct AgentQuotaSessionSection: View {
    let provider: AgentProvider
    let presentation: QuotaPresentation
    let valueMode: QuotaValueMode

    var body: some View {
        SettingsSection("Current quota") {
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .fiveHour,
                    window: presentation.fiveHour,
                    provider: provider,
                    valueMode: valueMode,
                    unavailableText: presentation.weekly == nil ? "Unavailable" : "Not active"
                )
            }
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .weekly,
                    window: presentation.weekly,
                    provider: provider,
                    valueMode: valueMode,
                    unavailableText: "Unavailable"
                )
            }
            SettingsSectionRow {
                SettingsPreferenceControlRow("Credits") {
                    Text(presentation.creditBalance ?? "Unavailable")
                        .monospacedDigit()
                }
            }
            SettingsSectionRow(showsDivider: false) {
                AgentResetCreditsRow(
                    provider: provider,
                    availableCount: presentation.availableResetCredits,
                    expiries: presentation.resetCreditExpiryDates
                )
            }
        }
    }
}
