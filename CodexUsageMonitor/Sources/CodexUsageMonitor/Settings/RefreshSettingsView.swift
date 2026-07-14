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
            SettingsSection("Current policy") {
                SettingsLabeledRow("Refresh frequency") {
                    Picker("Refresh frequency", selection: $settings.refreshMode) {
                        ForEach(RefreshMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }
                if let reason = viewModel.refreshScheduleReason {
                    SettingsLabeledRow("Effective policy") { Text(reason.displayName) }
                }
                if let interval = viewModel.effectiveRefreshInterval {
                    SettingsLabeledRow("Effective interval") { Text(Self.intervalName(interval)) }
                }
                SettingsLabeledRow("Activity") { Text(viewModel.settingsStatus.refreshActivity) }
                SettingsDescription("The monitor refreshes at launch, after wake, on schedule, and when requested manually.")
                SettingsDescription("Automatic may temporarily refresh every 30 seconds near a warning threshold, qualified exhaustion, or quota reset. Fixed choices never use 30 seconds.")
                SettingsDescription("After three unsuccessful refreshes, every mode temporarily retries every 10 minutes until an update is confirmed.")
            }

            SettingsSection("Latest collection") {
                SettingsLabeledRow("Status") { Text(viewModel.displayState.mode.displayName) }
                SettingsLabeledRow("Last attempt") {
                    Text(viewModel.displayState.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastConfirmedAt = viewModel.displayState.lastConfirmedAt {
                    SettingsLabeledRow("Last confirmed") {
                        Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                RefreshNowButton(viewModel: viewModel)
                    .padding(.leading, SettingsLayoutMetrics.valueColumnInset)
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
