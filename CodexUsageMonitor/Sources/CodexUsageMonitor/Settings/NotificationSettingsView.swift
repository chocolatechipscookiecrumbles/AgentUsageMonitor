import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    let setAlertsEnabled: (Bool) -> Void
    let openNotificationSettings: () -> Void

    var body: some View {
        SettingsPage {
            SettingsSection("Notifications") {
                Toggle("Enable quota notifications", isOn: Binding(
                    get: { settings.alertsEnabled },
                    set: { enabled in setAlertsEnabled(enabled) }
                ))
                if let message = settings.notificationAuthorizationState.statusMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(settings.notificationAuthorizationState == .denied ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 26)
                }
                if settings.notificationAuthorizationState == .denied {
                    Button("Open Notification Settings…", action: openNotificationSettings)
                        .padding(.leading, 26)
                }
            }

            SettingsSection("Remaining Quota") {
                ForEach(RemainingQuotaThreshold.allCases) { threshold in
                    Toggle(threshold.title, isOn: thresholdBinding(threshold))
                }
                SettingsDescription("Applies to both the 5-hour and weekly limits.")
                    .padding(.leading, 26)
            }
            .disabled(!settings.alertsEnabled)

            SettingsSection("Other Warnings") {
                Toggle("Forecasted exhaustion", isOn: $settings.forecastWarningsEnabled)
                Toggle("Reset-credit expiration", isOn: $settings.resetCreditWarningsEnabled)
                Toggle("Quota reset or reset failure", isOn: $settings.resetWarningsEnabled)
                Toggle("Stale quota data", isOn: $settings.staleDataWarningsEnabled)
                Toggle("Repeated refresh failures", isOn: $settings.refreshFailureWarningsEnabled)
            }
            .disabled(!settings.alertsEnabled)

            SettingsSection("Quiet Hours") {
                Toggle("Enable quiet hours", isOn: $settings.quietHoursEnabled)

                SettingsLabeledRow("Start") {
                    DatePicker("Start", selection: minuteBinding($settings.quietHoursStartMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .disabled(!settings.quietHoursEnabled)

                SettingsLabeledRow("End") {
                    DatePicker("End", selection: minuteBinding($settings.quietHoursEndMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .disabled(!settings.quietHoursEnabled)

                Toggle("Allow critical warnings", isOn: $settings.allowCriticalDuringQuietHours)
                    .disabled(!settings.quietHoursEnabled)

                SettingsDescription("Critical warnings are 5% remaining and a reset that failed verification.")
                    .padding(.leading, 26)
            }
            .disabled(!settings.alertsEnabled)
        }
    }

    private func thresholdBinding(_ threshold: RemainingQuotaThreshold) -> Binding<Bool> {
        Binding(
            get: { settings.isQuotaThresholdEnabled(threshold) },
            set: { settings.setQuotaThreshold(threshold, enabled: $0) }
        )
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
