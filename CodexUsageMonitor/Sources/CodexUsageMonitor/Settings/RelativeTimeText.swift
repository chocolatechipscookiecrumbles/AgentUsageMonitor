import Foundation

/// One relative-time renderer shared by every provider, so "last refresh"
/// cannot drift in wording between Codex and Claude.
enum RelativeTimeText {
    static func text(from date: Date, to now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) minute\(minutes == 1 ? "" : "s") ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hour\(hours == 1 ? "" : "s") ago" }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

extension RelativeTimeText {
    /// How long until `date`, for the left side of a reset row — the question
    /// "Resets" alone left unanswered. The absolute timestamp stays on the
    /// right, so the row gives both "how long" and "when".
    static func duration(until date: Date, from now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return "now" }
        if seconds < 60 { return "in under a minute" }

        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 { return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d" }
        if hours > 0 { return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h" }
        return "in \(minutes)m"
    }
}
