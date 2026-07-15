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
                Toggle("Extended update interruptions", isOn: $settings.refreshFailureWarningsEnabled)
                SettingsDescription("Alerts once after three unsuccessful refreshes, then retries every 10 minutes.")
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
}
