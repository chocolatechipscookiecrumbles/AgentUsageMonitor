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

            Section("Remaining Quota") {
                ForEach(RemainingQuotaThreshold.allCases) { threshold in
                    Toggle(threshold.title, isOn: thresholdBinding(threshold))
                }
                Text("Applies to both the 5-hour and weekly limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.alertsEnabled)

            Section {
                Toggle("Forecasted exhaustion", isOn: $settings.forecastWarningsEnabled)
                Toggle("Reset-credit expiration", isOn: $settings.resetCreditWarningsEnabled)
                Toggle("Quota reset or reset failure", isOn: $settings.resetWarningsEnabled)
                Toggle("Stale quota data", isOn: $settings.staleDataWarningsEnabled)
                Toggle("Repeated refresh failures", isOn: $settings.refreshFailureWarningsEnabled)
            } header: {
                Text("Other Warnings")
            } footer: {
                Color.clear.frame(height: 20)
            }
            .disabled(!settings.alertsEnabled)

            Section("Quiet Hours") {
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
