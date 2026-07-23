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
        let resetCreditExpiryDates: [Date]
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
            credits = Credits(
                balance: presentation.creditBalance,
                availableResetCredits: presentation.availableResetCredits,
                resetCreditExpiryDates: presentation.resetCreditExpiryDates
            )
        } else {
            credits = nil
        }

        isCached = displayState.mode == .cachedPaused
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
