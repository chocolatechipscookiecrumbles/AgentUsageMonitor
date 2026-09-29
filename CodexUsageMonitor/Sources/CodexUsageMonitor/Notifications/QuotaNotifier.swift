import Foundation
import UserNotifications

@MainActor
final class QuotaNotifier {
    private var center: UNUserNotificationCenter { .current() }
    private let defaults: UserDefaults
    private let settings: AppSettings
    private let policy = NotificationPolicy()
    private let addRequest: @MainActor (UNNotificationRequest) async throws -> Void
    private var inFlightKeys: Set<String> = []

    init(
        settings: AppSettings,
        defaults: UserDefaults = .standard,
        addRequest: @escaping @MainActor (UNNotificationRequest) async throws -> Void = {
            try await UNUserNotificationCenter.current().add($0)
        }
    ) {
        self.settings = settings
        self.defaults = defaults
        self.addRequest = addRequest
    }

    var alertsEnabled: Bool { settings.alertsEnabled }

    func refreshAuthorizationState() async -> NotificationAuthorizationState {
        let state = await authorizationState()
        settings.updateNotificationAuthorization(state)
        return state
    }

    func setAlertsEnabled(_ enabled: Bool) async -> NotificationAuthorizationState {
        guard enabled else {
            settings.alertsEnabled = false
            return await refreshAuthorizationState()
        }
        let existing = await authorizationState()
        switch existing {
        case .authorized:
            settings.alertsEnabled = true
            settings.updateNotificationAuthorization(.authorized)
            return .authorized
        case .denied:
            settings.updateNotificationAuthorization(.denied)
            return .denied
        case .notDetermined, .unknown:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let state = await refreshAuthorizationState()
            settings.alertsEnabled = state == .authorized
            return state
        case .unavailable:
            settings.updateNotificationAuthorization(.unavailable)
            return .unavailable
        }
    }

    func evaluate(
        _ record: QuotaRecord,
        interruptionState: RefreshInterruptionState,
        interruptionTransition: RefreshInterruptionTransition
    ) async {
        let presentation = record.presentation
        guard alertsEnabled else { return }
        for event in policy.evaluate(
            record,
            interruptionState: interruptionState,
            interruptionTransition: interruptionTransition
        ) where isEnabled(event) {
            await deliver(event)
        }
        guard presentation.confirmation.isTrusted else { return }
        if presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry {
            await quotaAlerts(provider: .codex, for: presentation.fiveHour, name: "5-hour")
            await quotaAlerts(provider: .codex, for: presentation.weekly, name: "Weekly")
        }
        if settings.resetCreditWarningsEnabled {
            for expiry in presentation.resetCreditExpiryDates {
                let seconds = expiry.timeIntervalSinceNow
                if seconds > 0, seconds <= 86_400 { await deliverOnce(key: "credit-\(expiry.timeIntervalSince1970)-24h", title: "Codex reset credit expires soon", body: "An earned reset credit expires within 24 hours.") }
                if seconds > 0, seconds <= 3_600 { await deliverOnce(key: "credit-\(expiry.timeIntervalSince1970)-1h", title: "Codex reset credit expires soon", body: "An earned reset credit expires within one hour.") }
            }
        }
        guard settings.forecastWarningsEnabled else { return }
        guard presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry else { return }
        await forecastAlert(record.fiveHourForecast, lane: "five-hour", limitID: presentation.limitID)
        await forecastAlert(record.weeklyForecast, lane: "weekly", limitID: presentation.limitID)
    }

    private func forecastAlert(_ forecast: QuotaForecast?, lane: String, limitID: String?) async {
        guard let forecast,
              forecast.confidence == .medium || forecast.confidence == .high,
              forecast.projectedExhaustionAt <= forecast.resetAt.addingTimeInterval(-15 * 60)
        else { return }
        let bucket = Int(forecast.projectedExhaustionAt.timeIntervalSince1970 / (15 * 60))
        await deliverOnce(
            key: "forecast-codex-\(limitID ?? "unknown")-\(lane)-\(forecast.resetAt.timeIntervalSince1970)-\(bucket)",
            title: "Codex usage may exhaust before reset",
            body: "The \(lane) limit is projected to run out before its current reset."
        )
    }

    /// Delivers Claude's remaining-quota threshold alerts for eligible live
    /// OAuth, fresh passive, and explicit manual CLI readings. Cached or stale
    /// readings are filtered before this shared authorization and dedup path.
    func evaluateClaudeThresholds(fiveHour: QuotaWindow?, weekly: QuotaWindow?) async {
        guard alertsEnabled else { return }
        await quotaAlerts(provider: .claudeCode, for: fiveHour, name: "5-hour")
        await quotaAlerts(provider: .claudeCode, for: weekly, name: "Weekly")
    }

    /// Confirms a settings change (e.g. "Will warn you when Claude reaches 25%").
    /// Unlike quota alerts this always delivers — it is direct feedback for an
    /// action the user just took, not a deduplicated recurring event.
    func deliverConfirmation(_ body: String) async {
        guard alertsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Quota Alerts"
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "quota-confirmation-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func quotaAlerts(provider: AgentProvider, for window: QuotaWindow?, name: String) async {
        for alert in QuotaThresholdEvaluator.alerts(
            provider: provider,
            window: window,
            name: name,
            isEnabled: { settings.isQuotaThresholdEnabled($0, for: provider) }
        ) {
            await deliverOnce(key: alert.key, title: alert.title, body: alert.body)
        }
    }

    private func isEnabled(_ event: NotificationEvent) -> Bool {
        if event.key.hasPrefix("reset-") { return settings.resetWarningsEnabled }
        if event.key.hasPrefix("stale-data-") { return settings.staleDataWarningsEnabled }
        if event.key.hasPrefix("refresh-interruption-") { return settings.refreshFailureWarningsEnabled }
        return true
    }

    private func deliver(_ event: NotificationEvent) async {
        await deliverOnce(key: event.key, title: event.title, body: event.body)
    }

    private func deliverOnce(key: String, title: String, body: String) async {
        guard !defaults.bool(forKey: key), inFlightKeys.insert(key).inserted else { return }
        defer { inFlightKeys.remove(key) }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
        do {
            try await addRequest(request)
            defaults.set(true, forKey: key)
        } catch {
            // Failed delivery remains eligible for the next evaluation.
        }
    }

    private func authorizationState() async -> NotificationAuthorizationState {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .authorized
        @unknown default:
            .unknown
        }
    }
}
