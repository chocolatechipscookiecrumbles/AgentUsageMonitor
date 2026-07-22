import Foundation

/// Pure presentation mapping for Claude usage — formatted strings and booleans
/// a view binds to, with no view logic. Keeps the freshness and scoping rules
/// (probe plan §7/§9, capability gate #3/#5) unit-testable.
struct ClaudeUsageDisplayModel {
    struct Window {
        let usedPercent: Int
        let usedText: String
        let hasReset: Bool
        let resetNote: String?
        let resetsAt: Date?
    }

    /// Anthropic exposes no remaining-credit figure — only spend, and an
    /// optional cap. The label must therefore say "used"; Codex's "Credits"
    /// label would imply a balance that does not exist.
    static let creditsUsedLabel = "Credits used"
    static let creditsUsedDescription = "Amount billed beyond your plan."

    /// Claude's five-hour window is not a fixed clock like Codex's: it starts
    /// at your first message and runs five hours from there, so the reset time
    /// moves with your usage rather than landing on the hour.
    static let fiveHourSessionNote = "Starts at your first message, then runs for five hours."

    /// Gate criterion #3: the weekly figure is not Claude Code only, so the
    /// UI must say what it covers rather than letting the user assume.
    static let weeklyScopeCaveat = "Weekly usage is shared with Claude chat, not Claude Code alone."

    let planText: String?
    let fiveHour: Window?
    let sevenDay: Window?
    let sourceLabel: String
    let capturedAtText: String
    let isLive: Bool
    /// Pay-as-you-go overage, already phrased as spend. `nil` when the
    /// endpoint omits it.
    let creditsUsedText: String?
    /// Non-nil whenever the data is not a live read, so the UI can never
    /// present a cached or passive result as current.
    let stalenessNotice: String?

    init(presentation: ClaudeUsagePresentation, now: Date = .now) {
        let snapshot = presentation.snapshot
        planText = snapshot.planHint.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        fiveHour = Self.window(snapshot.fiveHour, now: now)
        sevenDay = Self.window(snapshot.sevenDay, now: now)
        sourceLabel = Self.sourceLabel(delivery: presentation.delivery, source: snapshot.source)
        capturedAtText = RelativeTimeText.text(from: snapshot.capturedAt, to: now)
        isLive = presentation.delivery == .live
        creditsUsedText = Self.creditsUsed(snapshot.extraUsage)
        stalenessNotice = presentation.delivery == .live
            ? nil
            : "Live usage is temporarily unavailable; showing the last result."
    }

    /// Spend, optionally against its cap. Never phrased as remaining.
    private static func creditsUsed(_ raw: ClaudeExtraUsage?) -> String? {
        guard let raw else { return nil }
        guard raw.isEnabled else { return "Off" }
        let code = raw.currencyCode ?? "USD"
        let spent = currency(raw.usedCredits ?? 0, code: code)
        guard let limit = raw.monthlyLimit.map({ currency($0, code: code) }) else { return spent }
        return "\(spent) of \(limit)"
    }

    /// `formatted(.currency:)` rather than a NumberFormatter: same output,
    /// without allocating a formatter on every render pass.
    private static func currency(_ value: Double, code: String) -> String {
        value.formatted(.currency(code: code))
    }

    private static func window(_ limit: ClaudeLimitWindow?, now: Date) -> Window? {
        // A missing window stays missing: rendering it as 0% would be an
        // invented quota (gate criterion #5).
        guard let limit else { return nil }
        let hasReset = limit.resetsAt.map { $0 <= now } ?? false
        let percent = Int(limit.usedPercent.rounded())
        return Window(
            usedPercent: percent,
            usedText: "\(percent)%",
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
        case .cli: origin = "Claude Code CLI"
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

}
