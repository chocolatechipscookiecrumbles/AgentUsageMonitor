import SwiftUI

struct RefreshSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        _settings = ObservedObject(wrappedValue: viewModel.settings)
    }

    var body: some View {
        SettingsPage {
            SettingsSection("Automatic Refresh") {
                SettingsSectionRow {
                    SettingsPreferenceControlRow("Refresh interval") {
                        Picker("Refresh interval", selection: $settings.refreshMode) {
                            ForEach(RefreshMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: SettingsLayoutMetrics.controlWidth)
                        .accessibilityLabel("Refresh interval")
                    }
                }

                SettingsSectionRow {
                    SettingsUnavailablePreferenceControlRow(
                        "Refresh on wake",
                        description: "Immediately refresh after the system wakes from sleep.",
                        isOn: true,
                        availability: "Always on"
                    )
                }

                SettingsSectionRow(showsDivider: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        SettingsUnavailablePreferenceControlRow(
                            "Refresh on open",
                            description: "Refresh when the menu dropdown is opened.",
                            isOn: false,
                            availability: "Not available yet"
                        )
                        SettingsDescription("Refresh on wake is currently always enabled. Refresh on open is planned and does not refresh the menu yet.")
                    }
                }
            }

            SettingsSection("Current Policy") {
                if let reason = viewModel.refreshScheduleReason {
                    SettingsSectionRow {
                        SettingsLabeledRow("Effective policy") { Text(reason.displayName) }
                    }
                }
                if let interval = viewModel.effectiveRefreshInterval {
                    SettingsSectionRow {
                        SettingsLabeledRow("Effective interval") { Text(Self.intervalName(interval)) }
                    }
                }
                SettingsSectionRow {
                    SettingsLabeledRow("Activity") { Text(viewModel.settingsStatus.refreshActivity) }
                }
                SettingsSectionRow(showsDivider: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        SettingsDescription("The monitor refreshes at launch, after wake, on schedule, and when requested manually.")
                        SettingsDescription("Automatic may temporarily refresh every 30 seconds near a warning threshold, qualified exhaustion, or quota reset. Fixed choices never use 30 seconds.")
                        SettingsDescription("After three unsuccessful refreshes, every mode temporarily retries every 10 minutes until an update is confirmed.")
                    }
                }
            }

            SettingsSection("Latest Collection") {
                SettingsSectionRow {
                    SettingsLabeledRow("Status") { Text(viewModel.displayState.mode.displayName) }
                }
                SettingsSectionRow {
                    SettingsLabeledRow("Last attempt") {
                        Text(viewModel.displayState.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                if let lastConfirmedAt = viewModel.displayState.lastConfirmedAt {
                    SettingsSectionRow {
                        SettingsLabeledRow("Last confirmed") {
                            Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    RefreshNowButton(viewModel: viewModel)
                        .settingsValueColumnAligned()
                }
            }
        }
    }

    private static func intervalName(_ interval: TimeInterval) -> String {
        switch Int(interval) {
        case 30: "30 seconds"
        case 60: "1 minute"
        case 90: "1 minute 30 seconds"
        default: "\(Int(interval / 60)) minutes"
        }
    }
}
