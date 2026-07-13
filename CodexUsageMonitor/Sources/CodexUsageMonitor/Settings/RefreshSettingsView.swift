import SwiftUI

struct RefreshSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        _settings = ObservedObject(wrappedValue: viewModel.settings)
    }

    var body: some View {
        Form {
            Section("Current policy") {
                Picker("Refresh frequency", selection: $settings.refreshMode) {
                    ForEach(RefreshMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if let reason = viewModel.refreshScheduleReason {
                    LabeledContent("Effective policy", value: reason.displayName)
                }
                if let interval = viewModel.effectiveRefreshInterval {
                    LabeledContent("Effective interval", value: Self.intervalName(interval))
                }
                LabeledContent("Activity", value: viewModel.settingsStatus.refreshActivity)
                Text("The monitor refreshes at launch, after wake, on schedule, and when requested manually.")
                    .foregroundStyle(.secondary)
                Text("Automatic may temporarily refresh every 30 seconds near a warning threshold, qualified exhaustion, or quota reset. Fixed choices never use 30 seconds.")
                    .foregroundStyle(.secondary)
            }

            Section("Latest collection") {
                LabeledContent("Status", value: viewModel.displayState.mode.displayName)
                LabeledContent("Last attempt") {
                    Text(viewModel.displayState.lastAttemptAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let lastConfirmedAt = viewModel.displayState.lastConfirmedAt {
                    LabeledContent("Last confirmed") {
                        Text(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                Button(viewModel.isRefreshing ? "Refreshing…" : "Refresh now", action: viewModel.refresh)
                    .disabled(viewModel.isRefreshing)
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
