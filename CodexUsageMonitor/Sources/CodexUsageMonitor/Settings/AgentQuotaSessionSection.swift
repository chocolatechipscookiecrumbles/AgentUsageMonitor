import SwiftUI

/// Reusable quota/session card for a provider with an available presentation.
/// It deliberately uses only already-sanitized presentation fields.
///
/// Providers differ in what their credits figure *means*: Codex reports a
/// balance held, Anthropic reports spend against an optional cap. The label
/// is therefore a parameter, so a spend figure can never end up under a
/// balance label. Reset credits are Codex-only and omitted when `nil`.
struct AgentQuotaSessionSection: View {
    let provider: AgentProvider
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow?
    let valueMode: QuotaValueMode
    var creditsLabel: String = "Credits"
    var creditsDescription: String?
    var creditsValue: String?
    /// `nil` omits the reset-credits row entirely (providers without them).
    var resetCredits: AgentResetCredits?
    var weeklyFootnote: String?

    var body: some View {
        SettingsSection("Current quota") {
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .fiveHour,
                    window: fiveHour,
                    provider: provider,
                    valueMode: valueMode,
                    // An idle window reads as "not active" only when the
                    // provider is otherwise reporting; with nothing at all it
                    // is genuinely unavailable.
                    unavailableText: weekly == nil ? "Unavailable" : "Not active"
                )
            }
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .weekly,
                    window: weekly,
                    provider: provider,
                    valueMode: valueMode,
                    unavailableText: "Unavailable"
                )
            }
            if let weeklyFootnote {
                SettingsSectionRow {
                    SettingsDescription(weeklyFootnote)
                }
            }
            SettingsSectionRow(showsDivider: resetCredits != nil) {
                SettingsPreferenceControlRow(creditsLabel, description: creditsDescription) {
                    Text(creditsValue ?? "Unavailable")
                        .monospacedDigit()
                }
            }
            if let resetCredits {
                SettingsSectionRow(showsDivider: false) {
                    AgentResetCreditsRow(
                        provider: provider,
                        availableCount: resetCredits.availableCount,
                        expiries: resetCredits.expiries
                    )
                }
            }
        }
    }
}

/// Codex-only reset-credit data, grouped so providers without the concept
/// pass `nil` rather than threading two empty parameters.
struct AgentResetCredits {
    let availableCount: Int?
    let expiries: [Date]
}
