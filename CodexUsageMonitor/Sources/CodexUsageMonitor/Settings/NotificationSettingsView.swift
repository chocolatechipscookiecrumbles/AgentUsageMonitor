import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    let setAlertsEnabled: (Bool) -> Void
    let openNotificationSettings: () -> Void

    var body: some View {
        SettingsPage {
            SettingsSection("Notifications") {
                SettingsSectionRow(showsDivider: false) {
                    VStack(alignment: .leading, spacing: 8) {
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
                        }
                        if settings.notificationAuthorizationState == .denied {
                            Button("Open Notification Settings…", action: openNotificationSettings)
                        }
                    }
                }
            }

            SettingsSection("Other Warnings") {
                SettingsSectionRow {
                    SettingsPreferenceToggle("Forecasted exhaustion", isOn: $settings.forecastWarningsEnabled)
                }
                SettingsSectionRow {
                    SettingsPreferenceToggle("Reset-credit expiration", isOn: $settings.resetCreditWarningsEnabled)
                }
                SettingsSectionRow {
                    SettingsPreferenceToggle("Quota reset or reset failure", isOn: $settings.resetWarningsEnabled)
                }
                SettingsSectionRow {
                    SettingsPreferenceToggle("Stale quota data", isOn: $settings.staleDataWarningsEnabled)
                }
                SettingsSectionRow {
                    SettingsPreferenceToggle("Extended update interruptions", isOn: $settings.refreshFailureWarningsEnabled)
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription("Alerts once after three unsuccessful refreshes, then retries every 10 minutes.")
                }
            }
            .disabled(!settings.alertsEnabled)
        }
    }
}
