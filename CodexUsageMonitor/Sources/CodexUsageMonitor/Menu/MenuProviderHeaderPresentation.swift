import Foundation

struct MenuProviderHeaderPresentation {
    let title: String
    let subtitle: String
    let status: MenuPopoverStatus

    static func codex(
        displayState: QuotaDisplayState,
        connectionState: AgentConnectionState,
        isRefreshing: Bool
    ) -> Self {
        let presentation = displayState.displayedRecord?.presentation
        // The plan a live connection proves outranks the one carried on a quota
        // record, which may have been cached under an earlier subscription.
        let title = self.title(
            provider: .codex,
            connectionPlan: connectionState.accountPlanType,
            usagePlan: presentation?.planType
        )

        if isRefreshing {
            return Self(title: title, subtitle: "Refreshing…", status: .refreshing)
        }

        guard let presentation else {
            return Self(title: title, subtitle: "Usage unavailable", status: .unavailable)
        }

        return Self(
            title: title,
            subtitle: updatedText(for: presentation.collectedAt),
            status: displayState.mode == .confirmedCompleted ? .confirmed : .cached
        )
    }

    static func claude(
        usageState: ClaudeUsageState,
        connectionState: ClaudeConnectionState,
        isRefreshing: Bool
    ) -> Self {
        let presentation = usageState.presentation
        let title = self.title(
            provider: .claudeCode,
            connectionPlan: connectionState.accountPlanType,
            usagePlan: presentation?.snapshot.planHint
        )

        if isRefreshing {
            return Self(title: title, subtitle: "Refreshing…", status: .refreshing)
        }

        guard let presentation else {
            return Self(title: title, subtitle: "Usage unavailable", status: .unavailable)
        }

        // The Claude source label rides in the content caption, not here — the
        // header freshness line is identical across providers.
        return Self(
            title: title,
            subtitle: updatedText(for: presentation.snapshot.capturedAt),
            status: presentation.delivery == .live ? .confirmed : .cached
        )
    }

    /// The header names the *account*, because the tab directly above it
    /// already names the provider and repeating it says nothing.
    ///
    /// An unknown plan falls back to the provider name rather than to an empty
    /// line or a guess: not knowing the tier is a normal state before the first
    /// reading lands, and a blank header would read as a rendering fault.
    private static func title(
        provider: AgentProvider,
        connectionPlan: String?,
        usagePlan: String?
    ) -> String {
        AgentPlanName.display(connectionPlan)
            ?? AgentPlanName.display(usagePlan)
            ?? provider.tabTitle
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
