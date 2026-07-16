import SwiftUI

struct GeneralSettingsContextView: View {
    @ObservedObject var settings: AppSettings
    let status: SettingsStatus
    let displayState: QuotaDisplayState

    private var presentation: QuotaPresentation? {
        displayState.displayedRecord?.presentation
    }

    var body: some View {
        SettingsContextCard("Menu Bar Preview") {
            HStack {
                Text("Current label")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                MenuBarLabelView(
                    presentation: MenuBarLabelPresentation(
                        displayState: displayState,
                        style: settings.menuBarDisplayStyle,
                        valueMode: settings.quotaValueMode
                    )
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: .rect(cornerRadius: 6))
            }
        }

        SettingsContextCard("Current Usage") {
            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Plan",
                    value: presentation?.planType?.capitalized ?? "Unavailable"
                )
            )

            if let fiveHour = presentation?.fiveHour {
                Divider()
                SettingsQuotaPreviewRow(title: "5-Hour Window", window: fiveHour, tint: .green)
            }

            if let weekly = presentation?.weekly {
                Divider()
                SettingsQuotaPreviewRow(title: "Weekly Window", window: weekly, tint: .blue)
            }

            if presentation?.fiveHour == nil && presentation?.weekly == nil {
                SettingsDescription("No confirmed quota values are available for preview.")
            }
        }

        SettingsContextCard("Collection") {
            SettingsStatusBadge(
                title: displayState.mode.displayName,
                systemImage: displayState.mode == .confirmedCompleted ? "checkmark.circle.fill" : "pause.circle.fill",
                color: displayState.mode == .confirmedCompleted ? .green : .orange
            )
            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Last attempt",
                    value: status.lastAttemptAt.formatted(date: .omitted, time: .shortened)
                )
            )
        }
    }
}
