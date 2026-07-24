import SwiftUI

struct NotificationSettingsContextView: View {
    @ObservedObject var settings: AppSettings

    private var previewThreshold: RemainingQuotaThreshold? {
        RemainingQuotaThreshold.allCases.first { threshold in
            AppSettings.quotaThresholdProviders.contains { provider in
                settings.isQuotaThresholdEnabled(threshold, for: provider)
            }
        }
    }

    var body: some View {
        SettingsContextCard("Notification Preview") {
            if settings.alertsEnabled, let previewThreshold {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Five Hour Quota")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Sample: \(previewThreshold.title.lowercased())")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Both quota windows are monitored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .foregroundStyle(.orange)
                }
            } else {
                Label("Quota alert preview is disabled", systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.alertsEnabled && settings.resetCreditWarningsEnabled {
                SettingsPaletteDivider()
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Credit Expiry")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Sample advance-expiry warning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }

        SettingsContextCard("Delivery State") {
            SettingsStatusBadge(
                title: settings.alertsEnabled ? "Enabled" : "Disabled",
                systemImage: settings.alertsEnabled ? "bell.badge.fill" : "bell.slash.fill",
                color: settings.alertsEnabled ? .green : .secondary
            )
            SettingsContextValueRow(
                value: SettingsContextValue(
                    label: "Permission",
                    value: authorizationName
                )
            )
        }
    }

    private var authorizationName: String {
        switch settings.notificationAuthorizationState {
        case .unknown: "Checking"
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .unavailable: "Unavailable"
        }
    }
}
