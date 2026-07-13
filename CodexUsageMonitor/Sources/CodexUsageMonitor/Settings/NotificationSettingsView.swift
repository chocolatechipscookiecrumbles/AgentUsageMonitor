import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    let setAlertsEnabled: (Bool) -> Void
    let openNotificationSettings: () -> Void

    var body: some View {
        Form {
            Section(footer: Color.clear.frame(height: 20)) {
                Toggle("Enable quota notifications", isOn: Binding(
                    get: { settings.alertsEnabled },
                    set: { enabled in setAlertsEnabled(enabled) }
                ))
                if let message = settings.notificationAuthorizationState.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(settings.notificationAuthorizationState == .denied ? .orange : .secondary)
                }
                if settings.notificationAuthorizationState == .denied {
                    Button("Open Notification Settings…", action: openNotificationSettings)
                }
            }

            Section(footer: Color.clear.frame(height: 20)) {
                Toggle("Remaining quota warnings", isOn: $settings.thresholdWarningsEnabled)
                Text("Uses fixed thresholds at 50%, 25%, 10%, and 5% remaining.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Forecasted exhaustion", isOn: $settings.forecastWarningsEnabled)
                Toggle("Reset-credit expiration", isOn: $settings.resetCreditWarningsEnabled)
                Toggle("Quota reset or reset failure", isOn: $settings.resetWarningsEnabled)
                Toggle("Stale quota data", isOn: $settings.staleDataWarningsEnabled)
                Toggle("Repeated refresh failures", isOn: $settings.refreshFailureWarningsEnabled)
            }

            Section {
                Toggle("Enable quiet hours", isOn: $settings.quietHoursEnabled)

                LabeledContent("Start") {
                    DatePicker("", selection: minuteBinding($settings.quietHoursStartMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .disabled(!settings.quietHoursEnabled)

                LabeledContent("End") {
                    DatePicker("", selection: minuteBinding($settings.quietHoursEndMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .disabled(!settings.quietHoursEnabled)

                Toggle("Allow critical warnings", isOn: $settings.allowCriticalDuringQuietHours)
                    .disabled(!settings.quietHoursEnabled)

                Text("Critical warnings are 5% remaining and a reset that failed verification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}
