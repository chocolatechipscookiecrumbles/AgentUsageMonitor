import SwiftUI

/// Reusable per-agent "Remaining Quota" control. The caller supplies the
/// provider-scoped preference accessors so this visual component does not imply
/// a specific store. Styled after the approved chip mockup (Option A1): a
/// multi-select row of threshold chips with a blue selected state and a
/// checkmark.
struct AgentUsageWarningsSection: View {
    let provider: AgentProvider
    let alertsEnabled: Bool
    let isThresholdEnabled: (RemainingQuotaThreshold) -> Bool
    let setThresholdEnabled: (RemainingQuotaThreshold, Bool) -> Void

    var body: some View {
        SettingsSection("Remaining Quota") {
            SettingsSectionRow(showsDivider: false) {
                VStack(alignment: .leading, spacing: SettingsLayoutMetrics.agentWarningControlsSpacing) {
                    Text("Notify when remaining reaches")

                    HStack(spacing: SettingsLayoutMetrics.agentWarningChipSpacing) {
                        ForEach(RemainingQuotaThreshold.allCases) { threshold in
                            chip(for: threshold)
                        }
                    }

                    SettingsDescription("Applies to both the 5-hour and weekly limits.")
                }
            }
        }
        .disabled(!alertsEnabled)
    }

    private func chip(for threshold: RemainingQuotaThreshold) -> some View {
        let enabled = isThresholdEnabled(threshold)
        let shape = RoundedRectangle(cornerRadius: SettingsLayoutMetrics.agentWarningChipCornerRadius)

        return Button {
            setThresholdEnabled(threshold, !enabled)
        } label: {
            HStack(spacing: SettingsLayoutMetrics.agentWarningChipIconSpacing) {
                if enabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: SettingsLayoutMetrics.agentWarningChipCheckmarkSize, weight: .semibold))
                }
                Text("\(threshold.rawValue)%")
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
            .frame(height: SettingsLayoutMetrics.agentWarningChipHeight)
            .padding(.horizontal, SettingsLayoutMetrics.agentWarningChipHorizontalPadding)
            .background(shape.fill(enabled ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.12)))
            .overlay(shape.strokeBorder(enabled ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(provider.tabTitle), \(threshold.title)")
        .accessibilityValue(enabled ? "Enabled" : "Disabled")
        .accessibilityAddTraits(enabled ? .isSelected : [])
    }
}
