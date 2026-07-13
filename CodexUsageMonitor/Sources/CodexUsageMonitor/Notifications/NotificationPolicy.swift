import Foundation

enum NotificationSeverity: Sendable {
    case informational
    case warning
    case critical
}

struct NotificationEvent: Sendable {
    let key: String
    let title: String
    let body: String
    let severity: NotificationSeverity
}

@MainActor
final class NotificationPolicy {
    private var previousConfirmed: QuotaPresentation?
    private var consecutiveFailures = 0
    private var overdueResetObservations: [String: Int] = [:]

    func evaluate(_ record: QuotaRecord, now: Date = .now) -> [NotificationEvent] {
        let presentation = record.presentation
        var events: [NotificationEvent] = []

        if presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry {
            consecutiveFailures = 0
            if let previousConfirmed {
                events += resetEvents(previous: previousConfirmed, current: presentation, now: now)
            }
            previousConfirmed = presentation
        } else {
            consecutiveFailures += 1
        }

        if consecutiveFailures >= 3 {
            events.append(NotificationEvent(
                key: "refresh-failures-\(consecutiveFailures / 3)",
                title: "Codex quota refresh is failing",
                body: "The monitor has not obtained a confirmed live quota result in \(consecutiveFailures) consecutive refreshes.",
                severity: .warning
            ))
        }

        let age = now.timeIntervalSince(presentation.collectedAt)
        if age >= 15 * 60 {
            let bucket = Int(age / (15 * 60))
            events.append(NotificationEvent(
                key: "stale-data-\(Int(presentation.collectedAt.timeIntervalSince1970))-\(bucket)",
                title: "Codex quota data is stale",
                body: "The latest trusted quota snapshot is more than \(bucket * 15) minutes old.",
                severity: .warning
            ))
        }

        return events
    }

    private func resetEvents(previous: QuotaPresentation, current: QuotaPresentation, now: Date) -> [NotificationEvent] {
        [
            resetEvent(lane: "five-hour", previous: previous.fiveHour, current: current.fiveHour, now: now),
            resetEvent(lane: "weekly", previous: previous.weekly, current: current.weekly, now: now),
        ].compactMap { $0 }
    }

    private func resetEvent(lane: String, previous: QuotaWindow?, current: QuotaWindow?, now: Date) -> NotificationEvent? {
        guard let previous, let current, let previousReset = previous.resetAt, let currentReset = current.resetAt else { return nil }
        let resetKey = "\(lane)-\(Int(previousReset.timeIntervalSince1970))"

        if currentReset.timeIntervalSince(previousReset) > 120,
           current.remainingPercent > previous.remainingPercent {
            overdueResetObservations[resetKey] = nil
            return NotificationEvent(
                key: "reset-complete-\(resetKey)",
                title: "Codex \(lane) quota reset",
                body: "The provider has confirmed that the \(lane) quota window replenished.",
                severity: .informational
            )
        }

        guard now >= previousReset, abs(currentReset.timeIntervalSince(previousReset)) <= 120 else {
            overdueResetObservations[resetKey] = nil
            return nil
        }
        let count = (overdueResetObservations[resetKey] ?? 0) + 1
        overdueResetObservations[resetKey] = count
        guard count >= 2 else { return nil }
        return NotificationEvent(
            key: "reset-failed-\(resetKey)",
            title: "Codex \(lane) quota did not reset",
            body: "Two confirmed reads after the scheduled reset still report the previous quota window.",
            severity: .critical
        )
    }
}

extension AppSettings {
    func isWithinQuietHours(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if quietHoursStartMinutes == quietHoursEndMinutes { return true }
        if quietHoursStartMinutes < quietHoursEndMinutes {
            return minute >= quietHoursStartMinutes && minute < quietHoursEndMinutes
        }
        return minute >= quietHoursStartMinutes || minute < quietHoursEndMinutes
    }
}
