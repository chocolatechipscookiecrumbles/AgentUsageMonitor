import Foundation

/// A static, refresh-driven reset description. The popover never owns a timer,
/// so this string changes only with a new quota result or a new presentation.
struct MenuResetTimingPresentation {
    let resetAt: Date?
    let referenceDate: Date

    init(resetAt: Date?, referenceDate: Date = .now) {
        self.resetAt = resetAt
        self.referenceDate = referenceDate
    }

    var text: String {
        guard let resetAt else {
            return "Reset unavailable"
        }

        return "Resets \(resetAt.formatted(date: .omitted, time: .shortened)) · \(timeUntilReset)"
    }

    private var timeUntilReset: String {
        guard let resetAt else { return "Unavailable" }
        guard resetAt > referenceDate else { return "Resetting soon" }

        let components = Calendar.current.dateComponents(
            [.day, .hour, .minute],
            from: referenceDate,
            to: resetAt
        )
        var parts: [String] = []
        if let day = components.day, day > 0 {
            parts.append("\(day)d")
        }
        if let hour = components.hour, hour > 0 {
            parts.append("\(hour)h")
        }
        if parts.count < 2, let minute = components.minute, minute > 0 {
            parts.append("\(minute)m")
        }

        return parts.isEmpty ? "Less than 1m" : parts.joined(separator: " ")
    }
}
