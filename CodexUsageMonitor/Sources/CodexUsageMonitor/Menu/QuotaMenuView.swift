import AppKit
import SwiftUI

struct QuotaMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        Group {
            if let plan = viewModel.presentation.planType {
                Text("Codex plan: \(plan.capitalized)")
            } else {
                Text("Codex quota unavailable")
            }
            if let credits = viewModel.presentation.creditBalance {
                Text("Credits: \(credits)")
            }
            if let count = viewModel.presentation.availableResetCredits {
                Text("Available reset credits: \(count)")
            }
            ForEach(viewModel.presentation.resetCreditExpiryDates, id: \.self) { expiry in
                Text("Reset credit expires: \(expiry.formatted(date: .abbreviated, time: .shortened))")
            }
            Divider()
            QuotaWindowRow(
                title: "5-hour limit",
                window: viewModel.presentation.fiveHour,
                unavailableText: viewModel.presentation.weekly == nil ? "unavailable" : "not currently active",
                forecast: viewModel.fiveHourForecast
            )
            QuotaWindowRow(
                title: "Weekly limit",
                window: viewModel.presentation.weekly,
                unavailableText: "unavailable",
                forecast: viewModel.weeklyForecast
            )
            Divider()
            Text("Status: \(viewModel.displayState.mode.displayName)")
                .foregroundStyle(statusColor)
            if let pauseReason = viewModel.displayState.pauseReason {
                Text(pauseReason.displayName)
                    .font(.caption)
            }
            if viewModel.displayState.mode == .cachedPaused,
               let lastConfirmedAt = viewModel.displayState.lastConfirmedAt {
                Text("Last successful refresh: \(lastConfirmedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
            }
            NextRefreshCountdownView(
                lastRefreshAt: viewModel.displayState.lastAttemptAt,
                nextRefreshAt: viewModel.nextRefreshAt,
                isRefreshing: viewModel.isRefreshing
            )
            Toggle("Quota alerts", isOn: Binding(
                get: { viewModel.alertsEnabled },
                set: { viewModel.setAlertsEnabled($0) }
            ))
            if viewModel.notificationAuthorizationState == .denied {
                Text("Notifications disabled in System Settings")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Open Notification Settings…", action: viewModel.openNotificationSettings)
            }
            Button(viewModel.isRefreshing ? "Refreshing…" : "Refresh now", action: viewModel.refresh)
                .disabled(viewModel.isRefreshing)
            Divider()
            Button("Settings…", action: openNotificationSettings)
            Button("Quit Codex Usage Monitor") { NSApplication.shared.terminate(nil) }
        }
    }

    private func openNotificationSettings() {
        viewModel.settings.selectedSettingsTab = .notifications
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private var statusColor: Color {
        switch viewModel.displayState.mode {
        case .confirmedCompleted: .primary
        case .cachedPaused: .orange
        }
    }
}

private struct QuotaWindowRow: View {
    let title: String
    let window: QuotaWindow?
    let unavailableText: String
    let forecast: QuotaForecast?

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title): \(window.usedPercent)% used · \(window.remainingPercent)% remaining")
                if let resetAt = window.resetAt {
                    Text("Resets: \(resetAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                }
                if let forecast {
                    Text("Projected exhaustion: \(forecast.projectedExhaustionAt.formatted(date: .abbreviated, time: .shortened)) · \(forecast.confidence.rawValue) confidence")
                        .font(.caption)
                }
            }
        } else {
            Text("\(title): \(unavailableText)")
        }
    }
}
