import SwiftUI

/// Per-agent control over the menu popover's Token Monitor card.
///
/// It observes `AppSettings` directly for the same reason
/// `AgentUsageWarningsSection` does: a closure-only API leaves the controls in
/// a subtree that does not observe the store, so a tap animates without
/// changing state.
///
/// The master toggle is deliberately more than a display filter — turning it
/// off also stops reading that agent's local records — so the description says
/// so plainly rather than implying the app keeps watching either way.
struct AgentTokenMonitorSection: View {
    @ObservedObject var settings: AppSettings
    let provider: AgentProvider

    private var isVisible: Bool {
        settings.isTokenMonitorVisible(for: provider)
    }

    var body: some View {
        SettingsSection("Token Monitor") {
            SettingsSectionRow {
                SettingsPreferenceToggle(
                    "Show token monitor",
                    description: "Adds a Token Monitor card to \(provider.tabTitle)'s menu. Turning this off also stops reading \(provider.tabTitle)'s local records and removes what was cached for it.",
                    isOn: Binding(
                        get: { settings.isTokenMonitorVisible(for: provider) },
                        set: { settings.setTokenMonitorVisible($0, for: provider) }
                    )
                )
            }

            SettingsSectionRow {
                SettingsPreferenceControlRow(
                    "Range",
                    description: "Whether the card reports today or the current week. Both are read from the same local records on this Mac."
                ) {
                    Picker("Range", selection: Binding(
                        get: { settings.tokenMonitorRange(for: provider) },
                        set: { settings.setTokenMonitorRange($0, for: provider) }
                    )) {
                        ForEach(TokenMonitorRange.allCases) { range in
                            Text(range.settingsTitle).tag(range)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: SettingsLayoutMetrics.compactSegmentedControlWidth)
                }
                .disabled(!isVisible)
            }

            ForEach(Array(TokenMonitorSection.allCases.enumerated()), id: \.element) { index, section in
                SettingsSectionRow(showsDivider: index < TokenMonitorSection.allCases.count - 1) {
                    SettingsPreferenceToggle(
                        section.title,
                        description: section.settingsDescription,
                        isOn: Binding(
                            get: { settings.isTokenMonitorSectionEnabled(section, for: provider) },
                            set: { settings.setTokenMonitorSection(section, enabled: $0, for: provider) }
                        )
                    )
                    // Disabling the whole section would also disable the master
                    // toggle above, leaving no way back on.
                    .disabled(!isVisible)
                }
            }
        }
    }
}
