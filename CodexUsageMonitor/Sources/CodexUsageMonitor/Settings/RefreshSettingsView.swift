import SwiftUI

struct RefreshSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        Form {
            Section("Current policy") {
                LabeledContent("Scheduled interval", value: "Every 5 minutes")
                LabeledContent("Activity", value: viewModel.settingsStatus.refreshActivity)
                Text("The monitor refreshes at launch, after wake, on schedule, and when requested manually.")
                    .foregroundStyle(.secondary)
            }

            Section("Latest collection") {
                LabeledContent("Verification", value: viewModel.presentation.confirmation.displayName)
                LabeledContent("Collected") {
                    Text(viewModel.presentation.collectedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Button(viewModel.isRefreshing ? "Refreshing…" : "Refresh now", action: viewModel.refresh)
                    .disabled(viewModel.isRefreshing)
            }

            Section("Planned controls") {
                Text("Fixed and automatic interval choices arrive in the Adaptive Refresh phase after their scheduling behavior is implemented.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
