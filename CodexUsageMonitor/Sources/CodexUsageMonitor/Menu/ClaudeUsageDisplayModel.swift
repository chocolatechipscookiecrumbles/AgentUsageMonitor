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

    /// Anthropic's pay-as-you-go overage ("extra usage").
    ///
    /// Deliberately *not* modelled on Codex's credits. Codex reports a
    /// balance you hold; this reports money already **spent** against an
    /// optional monthly cap. Presenting `usedCredits: 0` as a "balance" would
    /// invert its meaning — it means nothing spent, not nothing left.
    struct ExtraUsage {
        let isEnabled: Bool
        let spentText: String
        let limitText: String?
        let summaryText: String
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
    /// Pay-as-you-go overage, when the endpoint reports it.
    let extraUsage: ExtraUsage?
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
        extraUsage = Self.extra(snapshot.extraUsage)
        stalenessNotice = presentation.delivery == .live
            ? nil
            : "Live usage is temporarily unavailable; showing the last result."
    }

    private static func extra(_ raw: ClaudeExtraUsage?) -> ExtraUsage? {
        guard let raw else { return nil }
        guard raw.isEnabled else {
            return ExtraUsage(isEnabled: false, spentText: "—", limitText: nil, summaryText: "Off")
        }
        let code = raw.currencyCode ?? "USD"
        let spent = currency(raw.usedCredits ?? 0, code: code)
        let limit = raw.monthlyLimit.map { currency($0, code: code) }
        // Always phrased as spend. Never "remaining" — that would invert it.
        let summary = limit.map { "\(spent) of \($0) spent" } ?? "\(spent) spent"
        return ExtraUsage(isEnabled: true, spentText: spent, limitText: limit, summaryText: summary)
    }

    private static func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(code)"
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
