import Foundation

/// The display-ready Codex portion of the popover.
///
/// Values remain optional until the collector has actually supplied them: a
/// missing lane or credit value is represented as unavailable rather than a
/// synthetic zero.
struct CodexMenuPresentation {
    struct Window {
        let title: String
        let value: Value
        let forecast: QuotaForecast?

        enum Value {
            case available(usedPercent: Int, resetAt: Date?)
            case unavailable(message: String)
        }
    }

    struct Credits {
        let balance: String?
        let availableResetCredits: Int?
        let visibleResetCreditExpiryDates: [Date]
        let hiddenResetCreditExpiryCount: Int
    }

    let windows: [Window]
    let credits: Credits?
    let isCached: Bool

    init?(
        displayState: QuotaDisplayState,
        fiveHourForecast: QuotaForecast?,
        weeklyForecast: QuotaForecast?
    ) {
        guard let presentation = displayState.displayedRecord?.presentation else {
            return nil
        }

        windows = [
            Window(
                title: "Five Hour Window",
                value: Self.windowValue(
                    presentation.fiveHour,
                    unavailableMessage: presentation.weekly == nil
                        ? "Usage unavailable"
                        : "Not currently active"
                ),
                forecast: fiveHourForecast
            ),
            Window(
                title: "Weekly Window",
                value: Self.windowValue(
                    presentation.weekly,
                    unavailableMessage: "Usage unavailable"
                ),
                forecast: weeklyForecast
            ),
        ]

        if presentation.creditBalance != nil
            || presentation.availableResetCredits != nil
            || !presentation.resetCreditExpiryDates.isEmpty {
            let sortedExpiries = presentation.resetCreditExpiryDates.sorted()
            let visibleExpiries = Array(
                sortedExpiries.prefix(MenuPopoverTheme.maximumVisibleResetCreditExpiries)
            )
            credits = Credits(
                balance: Self.roundedBalance(presentation.creditBalance),
                availableResetCredits: presentation.availableResetCredits,
                visibleResetCreditExpiryDates: visibleExpiries,
                hiddenResetCreditExpiryCount: sortedExpiries.count - visibleExpiries.count
            )
        } else {
            credits = nil
        }

        isCached = displayState.mode == .cachedPaused
    }

    /// The popover shows a compact balance rounded to 4 significant figures;
    /// Settings keeps the full-precision string. A non-numeric balance (an
    /// unexpected currency-formatted string) is passed through untouched rather
    /// than dropped.
    private static func roundedBalance(_ raw: String?) -> String? {
        guard let raw else { return nil }
        guard let value = Double(raw) else { return raw }
        return value.formatted(.number.precision(.significantDigits(1...4)))
    }

    private static func windowValue(
        _ window: QuotaWindow?,
        unavailableMessage: String
    ) -> Window.Value {
        guard let window else {
            return .unavailable(message: unavailableMessage)
        }
        return .available(
            usedPercent: min(max(window.usedPercent, 0), 100),
            resetAt: window.resetAt
        )
    }
}
