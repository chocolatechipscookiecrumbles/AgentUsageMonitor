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

    /// Spending and its optional cap are separate from a prepaid balance.
    static let creditsUsedLabel = "Usage-credit spending"
    static let creditsUsedDescription = "Reported spending beyond your plan."

    /// Claude's five-hour window is not a fixed clock like Codex's: it starts
    /// at your first message and runs five hours from there, so the reset time
    /// moves with your usage rather than landing on the hour.
    static let fiveHourSessionNote = "Starts at your first message, then runs for five hours."

    /// The note explains a window that has not begun yet, so it is only
    /// correct in that one state.
    ///
    /// `fiveHour == nil` conflates three things: no session started, the
    /// window already reset, and the provider being unavailable. The payload
    /// cannot tell them apart, so the safe rule is to require a working
    /// connection: with live data and no five-hour window, "not started" is
    /// the only remaining explanation. When nothing is available at all the
    /// note would be noise on top of an error.
    static func showsFiveHourSessionNote(isConnected: Bool, hasFiveHourWindow: Bool) -> Bool {
        isConnected && !hasFiveHourWindow
    }

    /// Gate criterion #3: the weekly figure is not Claude Code only, so the
    /// UI must say what it covers rather than letting the user assume.
    static let weeklyScopeCaveat = "Weekly usage is shared with Claude chat."

    let planText: String?
    let fiveHour: Window?
    let sevenDay: Window?
    let sourceLabel: String
    let capturedAtText: String
    let isLive: Bool
    /// Pay-as-you-go overage, already phrased as spend. `nil` when the
    /// endpoint omits it.
    let creditsUsedText: String?
    let monthlySpendingLimitText: String?
    let financialUpdatedText: String?
    /// Non-nil whenever the data is not a live read, so the UI can never
    /// present a cached or passive result as current.
    let stalenessNotice: String?

    init(presentation: ClaudeUsagePresentation, now: Date = .now) {
        let snapshot = presentation.snapshot
        planText = AgentPlanName.display(snapshot.planHint)
        fiveHour = Self.window(snapshot.fiveHour, now: now)
        sevenDay = Self.window(snapshot.sevenDay, now: now)
        sourceLabel = Self.sourceLabel(delivery: presentation.delivery, source: snapshot.source)
        capturedAtText = RelativeTimeText.text(from: snapshot.capturedAt, to: now)
        isLive = presentation.delivery == .live
        creditsUsedText = Self.creditsUsed(snapshot.extraUsage)
        monthlySpendingLimitText = snapshot.extraUsage.map {
            Self.currency($0.monthlyLimit, code: $0.currencyCode)
        }
        financialUpdatedText = snapshot.extraUsage.map { _ in
            (snapshot.extraUsageObservedAt ?? snapshot.capturedAt).formatted(date: .abbreviated, time: .shortened)
        }
        // Prefer the collector's specific cause over the generic sentence. A
        // refresh that produced no live reading should say *why* — rate limited,
        // Keychain denied, credential rejected — so the user knows whether to
        // wait or to act, instead of pressing a button that appears inert.
        stalenessNotice = presentation.warnings.first
            ?? (presentation.delivery == .cached ? "Showing the last saved reading." : nil)
    }

    /// Never invent an amount or currency when either field is absent.
    private static func creditsUsed(_ raw: ClaudeExtraUsage?) -> String? {
        guard let raw else { return nil }
        guard raw.isEnabled else { return "Off" }
        return currency(raw.usedCredits, code: raw.currencyCode)
    }

    /// `formatted(.currency:)` rather than a NumberFormatter: same output,
    /// without allocating a formatter on every render pass.
    private static func currency(_ value: Double?, code: String?) -> String {
        guard let value, value.isFinite, value >= 0,
              let code, Locale.commonISOCurrencyCodes.contains(code) else { return "Unavailable" }
        return value.formatted(.currency(code: code))
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
