import Foundation
import UserNotifications

@MainActor
final class QuotaNotifier {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "alertsEnabled"

    var alertsEnabled: Bool { defaults.bool(forKey: enabledKey) }

    func setAlertsEnabled(_ enabled: Bool) async {
        guard enabled else {
            defaults.set(false, forKey: enabledKey)
            return
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        defaults.set(granted, forKey: enabledKey)
    }

    func evaluate(_ presentation: QuotaPresentation) async {
        guard alertsEnabled, presentation.confirmation.isTrusted else { return }
        await quotaAlerts(for: presentation.fiveHour, name: "5-hour")
        await quotaAlerts(for: presentation.weekly, name: "Weekly")
        for expiry in presentation.resetCreditExpiryDates {
            let seconds = expiry.timeIntervalSinceNow
            if seconds > 0, seconds <= 86_400 { await deliverOnce(key: "credit-\(expiry.timeIntervalSince1970)-24h", title: "Codex reset credit expires soon", body: "An earned reset credit expires within 24 hours.") }
            if seconds > 0, seconds <= 3_600 { await deliverOnce(key: "credit-\(expiry.timeIntervalSince1970)-1h", title: "Codex reset credit expires soon", body: "An earned reset credit expires within one hour.") }
        }
    }

    private func quotaAlerts(for window: QuotaWindow?, name: String) async {
        guard let window, let resetAt = window.resetAt else { return }
        for threshold in [25, 10, 5] where window.remainingPercent <= threshold {
            await deliverOnce(
                key: "quota-\(name)-\(resetAt.timeIntervalSince1970)-\(threshold)",
                title: "Codex \(name) limit is low",
                body: "\(window.remainingPercent)% remains before the current limit resets."
            )
        }
    }

    private func deliverOnce(key: String, title: String, body: String) async {
        guard !defaults.bool(forKey: key) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
        if (try? await center.add(request)) != nil { defaults.set(true, forKey: key) }
    }
}
