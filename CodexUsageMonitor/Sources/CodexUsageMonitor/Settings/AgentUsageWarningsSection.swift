import SwiftUI

/// Reusable provider-page warning controls. The caller supplies the preference
/// scope so this visual component does not imply a provider-specific store.
struct AgentUsageWarningsSection: View {
    let provider: AgentProvider
    let alertsEnabled: Bool
    let isThresholdEnabled: (RemainingQuotaThreshold) -> Bool
    let setThresholdEnabled: (RemainingQuotaThreshold, Bool) -> Void

    var body: some View {
        SettingsSection("Usage Warnings") {
            SettingsSectionRow(showsDivider: false) {
                VStack(alignment: .leading, spacing: SettingsLayoutMetrics.agentWarningControlsSpacing) {
                    SettingsDescription("Alert when quota drops below these thresholds.")

                    HStack(spacing: SettingsLayoutMetrics.agentWarningChipSpacing) {
                        ForEach(RemainingQuotaThreshold.allCases) { threshold in
                            warningChip(for: threshold)
                        }
                    }
                }
            }
        }
        .disabled(!alertsEnabled)
    }

    private func warningChip(for threshold: RemainingQuotaThreshold) -> some View {
        let enabled = isThresholdEnabled(threshold)

        return Button {
            setThresholdEnabled(threshold, !enabled)
        } label: {
            Text("\(threshold.rawValue)%")
                .frame(width: SettingsLayoutMetrics.agentWarningChipWidth)
        }
        .buttonStyle(.borderedProminent)
        .tint(enabled ? provider.settingsPresentationTint : .secondary)
        .opacity(enabled ? 1 : SettingsLayoutMetrics.agentWarningDisabledChipOpacity)
        .accessibilityLabel(threshold.title)
        .accessibilityValue(enabled ? "Enabled" : "Disabled")
    }
}
