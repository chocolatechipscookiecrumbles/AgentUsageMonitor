import Foundation

/// Whether the Token Monitor reports the current local day or the current local
/// week.
///
/// The range decides which observed requests are in scope and how wide one
/// chart bar is. It never changes what was observed: both views are derived
/// from the same reconciled request set, so switching between them can only
/// widen or narrow the window, never introduce a number that was not read from
/// local records.
enum TokenMonitorRange: String, CaseIterable, Identifiable, Sendable {
    case day
    case week

    var id: Self { self }

    /// The line under the card's title. It replaces a fixed provenance string,
    /// so it has to name the window the totals cover.
    var scope: String {
        switch self {
        case .day: "Today"
        case .week: "This week"
        }
    }

    var settingsTitle: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        }
    }

    var emptyMessage: String {
        switch self {
        case .day: "No activity observed today"
        case .week: "No activity observed this week"
        }
    }

    var totalAccessibilityLabel: String {
        switch self {
        case .day: "Tokens today"
        case .week: "Tokens this week"
        }
    }

    var chartAccessibilityLabel: String {
        switch self {
        case .day: "Activity chart, 30-minute intervals since midnight"
        case .week: "Activity chart, one bar per day since the start of the week"
        }
    }

    /// The calendar component whose current interval bounds the range.
    var intervalComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        }
    }

    /// The width of one chart bar, as a calendar step rather than a count of
    /// seconds. Stepping through the calendar is what keeps a daylight-saving
    /// day at exactly one bar in the week view instead of one and a fraction.
    var bucketStep: (component: Calendar.Component, value: Int) {
        switch self {
        case .day: (.minute, 30)
        case .week: (.day, 1)
        }
    }

    /// The single stepping rule, so the aggregation that fills buckets and the
    /// presentation that sizes an empty chart's domain can never disagree about
    /// where a bar ends. `nil` means the calendar could not advance, which is
    /// treated as unreadable rather than silently skipped.
    func bucketEnd(after start: Date, calendar: Calendar) -> Date? {
        guard let next = calendar.date(
            byAdding: bucketStep.component,
            value: bucketStep.value,
            to: start
        ), next > start else { return nil }
        return next
    }
}
