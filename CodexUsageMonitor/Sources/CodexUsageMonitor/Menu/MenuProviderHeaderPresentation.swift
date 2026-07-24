import Foundation

struct MenuProviderHeaderPresentation {
    let title: String
    let subtitle: String
    let status: MenuPopoverStatus

    static func codex(
        displayState: QuotaDisplayState,
        isRefreshing: Bool
    ) -> Self {
        if isRefreshing {
            return Self(
                title: "Codex",
                subtitle: "Refreshing…",
                status: .refreshing
            )
        }

        guard let presentation = displayState.displayedRecord?.presentation else {
            return Self(
                title: "Codex",
                subtitle: "Usage unavailable",
                status: .unavailable
            )
        }

        return Self(
            title: "Codex",
            subtitle: updatedText(for: presentation.collectedAt),
            status: displayState.mode == .confirmedCompleted ? .confirmed : .cached
        )
    }

    static func claude(
        usageState: ClaudeUsageState,
        isRefreshing: Bool
    ) -> Self {
        if isRefreshing {
            return Self(
                title: "Claude",
                subtitle: "Refreshing…",
                status: .refreshing
            )
        }

        guard let presentation = usageState.presentation else {
            return Self(
                title: "Claude",
                subtitle: "Usage unavailable",
                status: .unavailable
            )
        }

        // The Claude source label rides in the content caption, not here — the
        // header freshness line is identical across providers.
        return Self(
            title: "Claude",
            subtitle: updatedText(for: presentation.snapshot.capturedAt),
            status: presentation.delivery == .live ? .confirmed : .cached
        )
    }

    /// The one freshness line every provider shares: an absolute timestamp and
    /// the relative "how long ago", computed once at render (the popover owns no
    /// timer, so it does not tick while open).
    private static func updatedText(for date: Date) -> String {
        // `.shortened` drops the seconds — the relative half already conveys
        // recency, so second-level precision on the absolute time is noise.
        "Updated: \(date.formatted(date: .omitted, time: .shortened)) · \(RelativeTimeText.text(from: date))"
    }
}
