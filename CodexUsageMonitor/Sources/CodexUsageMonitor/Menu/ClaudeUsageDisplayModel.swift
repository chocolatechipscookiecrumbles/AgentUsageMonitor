import Foundation

/// Pure presentation mapping for Claude usage — formatted strings and booleans
/// a view binds to, with no view logic. Keeps the freshness and scoping rules
/// (probe plan §7/§9, capability gate #3/#5) unit-testable.
struct ClaudeUsageDisplayModel {
    struct Window {
        let usedText: String
        let hasReset: Bool
        let resetNote: String?
        let resetsAt: Date?
    }

    /// Gate criterion #3: the weekly figure is not Claude Code only, so the
    /// UI must say what it covers rather than letting the user assume.
    static let weeklyScopeCaveat = "Weekly usage is shared with Claude chat, not Claude Code alone."

    let planText: String?
    let fiveHour: Window?
    let sevenDay: Window?
    let sourceLabel: String
    let capturedAtText: String
    let isLive: Bool
    /// Non-nil whenever the data is not a live read, so the UI can never
    /// present a cached or passive result as current.
    let stalenessNotice: String?

    init(presentation: ClaudeUsagePresentation, now: Date = .now) {
        let snapshot = presentation.snapshot
        planText = snapshot.planHint.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        fiveHour = Self.window(snapshot.fiveHour, now: now)
        sevenDay = Self.window(snapshot.sevenDay, now: now)
        sourceLabel = Self.sourceLabel(delivery: presentation.delivery, source: snapshot.source)
        capturedAtText = Self.relativeText(from: snapshot.capturedAt, to: now)
        isLive = presentation.delivery == .live
        stalenessNotice = presentation.delivery == .live
            ? nil
            : "Live usage is temporarily unavailable; showing the last result."
    }

    private static func window(_ limit: ClaudeLimitWindow?, now: Date) -> Window? {
        // A missing window stays missing: rendering it as 0% would be an
        // invented quota (gate criterion #5).
        guard let limit else { return nil }
        let hasReset = limit.resetsAt.map { $0 <= now } ?? false
        return Window(
            usedText: "\(Int(limit.usedPercent.rounded()))%",
            hasReset: hasReset,
            resetNote: hasReset ? "This window has since reset." : nil,
            resetsAt: limit.resetsAt
        )
    }

    private static func sourceLabel(delivery: ClaudeUsageDelivery, source: ClaudeUsageSource) -> String {
        let origin: String
        switch source {
        case .oauth: origin = "Claude OAuth"
        case .statusLine: origin = "Claude Code capture"
        case .cache: origin = "cached result"
        }
        switch delivery {
        case .live, .passiveSnapshot:
            return origin
        case .cached:
            // Names where the data came from *and* that it is not fresh.
            return "Cached \(origin) result"
        }
    }

    private static func relativeText(from date: Date, to now: Date) -> String {
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
