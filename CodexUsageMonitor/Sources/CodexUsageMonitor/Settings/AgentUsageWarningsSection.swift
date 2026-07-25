import SwiftUI

/// Reusable per-agent "Remaining Quota" control. It observes `AppSettings`
/// directly so toggling a chip re-renders immediately (a closure-only API left
/// the chips in a subtree that did not observe the store, so taps showed only a
/// press animation with no state change). Styled after the approved chip mockup
/// (Option A1): a multi-select row of threshold chips with a blue selected
/// state and a checkmark.
struct AgentUsageWarningsSection: View {
    @ObservedObject var settings: AppSettings
    let provider: AgentProvider

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
        .disabled(!settings.alertsEnabled)
    }

    private func chip(for threshold: RemainingQuotaThreshold) -> some View {
        let enabled = settings.isQuotaThresholdEnabled(threshold, for: provider)
        let shape = RoundedRectangle(cornerRadius: SettingsLayoutMetrics.agentWarningChipCornerRadius)

        return Button {
            settings.setQuotaThreshold(threshold, enabled: !enabled, for: provider)
        } label: {
            HStack(spacing: SettingsLayoutMetrics.agentWarningChipIconSpacing) {
                Image(systemName: enabled ? "checkmark" : "plus")
                    .font(.system(size: SettingsLayoutMetrics.agentWarningChipCheckmarkSize, weight: .semibold))
                Text("\(threshold.rawValue)%")
            }
            .font(.callout.weight(enabled ? .semibold : .regular))
            .foregroundStyle(enabled ? Color.white : Color.secondary)
            .frame(height: SettingsLayoutMetrics.agentWarningChipHeight)
            .padding(.horizontal, SettingsLayoutMetrics.agentWarningChipHorizontalPadding)
            .background(shape.fill(enabled ? Color.accentColor : Color.secondary.opacity(0.12)))
            .overlay(shape.strokeBorder(enabled ? .clear : Color.secondary.opacity(0.35), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: enabled)
        .accessibilityLabel("\(provider.tabTitle), \(threshold.title)")
        .accessibilityValue(enabled ? "On" : "Off")
        .accessibilityAddTraits(enabled ? .isSelected : [])
    }
}
