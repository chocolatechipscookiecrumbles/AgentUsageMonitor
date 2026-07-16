import SwiftUI

struct RefreshSettingsContextView: View {
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        SettingsContextCard("Current State") {
            SettingsStatusBadge(
                title: viewModel.displayState.mode.displayName,
                systemImage: stateSystemImage,
                color: stateColor
            )

            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Last attempt",
                    value: viewModel.displayState.lastAttemptAt.formatted(date: .omitted, time: .shortened)
                )
            )

            if let lastConfirmedAt = viewModel.displayState.lastConfirmedAt {
                SettingsContextValueRow(
                    value: SettingsContextValue(
                        label: "Last confirmed",
                        value: lastConfirmedAt.formatted(date: .omitted, time: .shortened)
                    )
                )
            }

            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Activity",
                    value: viewModel.settingsStatus.refreshActivity
                )
            )
        }

        SettingsContextCard("Schedule") {
            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Selected",
                    value: viewModel.settings.refreshMode.displayName
                )
            )

            if let interval = viewModel.effectiveRefreshInterval {
                SettingsContextValueRow(
                    value: SettingsContextValue(
                        label: "Effective",
                        value: intervalName(interval)
                    )
                )
            }

            if let reason = viewModel.refreshScheduleReason {
                SettingsDescription(reason.displayName)
            }
        }
    }

    private var stateSystemImage: String {
        switch viewModel.displayState.mode {
        case .confirmedCompleted: "checkmark.circle.fill"
        case .cachedPaused: "pause.circle.fill"
        }
    }

    private var stateColor: Color {
        switch viewModel.displayState.mode {
        case .confirmedCompleted: .green
        case .cachedPaused: .orange
        }
    }

    private func intervalName(_ interval: TimeInterval) -> String {
        switch Int(interval) {
        case 30: "30 seconds"
        case 60: "1 minute"
        case 90: "1 minute 30 seconds"
        default: "\(Int(interval / 60)) minutes"
        }
    }
}
