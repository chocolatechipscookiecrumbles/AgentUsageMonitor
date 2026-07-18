import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    let setAlertsEnabled: (Bool) -> Void
    let openNotificationSettings: () -> Void

    var body: some View {
        SettingsPage {
            SettingsSection("Notifications") {
                SettingsPreferenceToggle(
                    "Enable quota notifications",
                    description: "Allow quota alerts after macOS notification permission is granted.",
                    isOn: Binding(
                        get: { settings.alertsEnabled },
                        set: { enabled in setAlertsEnabled(enabled) }
                    )
                )
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
                    SettingsPreferenceToggle(threshold.title, isOn: thresholdBinding(threshold))
                }
                SettingsDescription("Applies to both the 5-hour and weekly limits.")
                    .padding(.leading, 26)
            }
            .disabled(!settings.alertsEnabled)

            SettingsSection("Other Warnings") {
                SettingsPreferenceToggle("Forecasted exhaustion", isOn: $settings.forecastWarningsEnabled)
                SettingsPreferenceToggle("Reset-credit expiration", isOn: $settings.resetCreditWarningsEnabled)
                SettingsPreferenceToggle("Quota reset or reset failure", isOn: $settings.resetWarningsEnabled)
                SettingsPreferenceToggle("Stale quota data", isOn: $settings.staleDataWarningsEnabled)
                SettingsPreferenceToggle("Extended update interruptions", isOn: $settings.refreshFailureWarningsEnabled)
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
