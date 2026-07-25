import Foundation

/// Chooses which single provider the text / single-provider menu-bar styles
/// display, and whether the General-settings provider selector should appear.
///
/// A provider is *eligible* ("connected" for menu-bar purposes) when it
/// currently has a usable reading — the same `MenuProviderSummary` availability
/// the other menu-bar surfaces use. A provider with no reading cannot show a
/// 5-hour / weekly value, and app-local disconnect blanks the reading, so a
/// disconnected provider is naturally excluded.
enum MenuBarProviderSelection {
    /// Eligible providers in canonical order (Codex, then Claude). Only
    /// providers with a real data source can ever appear here.
    static func eligibleProviders(
        codexDisplayState: QuotaDisplayState,
        claudeState: ClaudeUsageState,
        now: Date = .now
    ) -> [AgentProvider] {
        var providers: [AgentProvider] = []
        if MenuProviderSummary.codex(displayState: codexDisplayState).usedPercent != nil {
            providers.append(.codex)
        }
        if MenuProviderSummary.claude(usageState: claudeState, now: now).usedPercent != nil {
            providers.append(.claudeCode)
        }
        return providers
    }

    /// The provider whose data the label should render, given the user's stored
    /// choice and the currently eligible providers.
    ///
    /// - The stored choice wins when it is still eligible.
    /// - Otherwise the sole eligible provider is used, so a single connected
    ///   provider shows without the user configuring anything.
    /// - When nothing is eligible the stored choice is kept, so the label shows
    ///   that provider's placeholder rather than jumping around while data loads.
    static func effectiveProvider(
        stored: AgentProvider,
        eligible: [AgentProvider]
    ) -> AgentProvider {
        if eligible.contains(stored) { return stored }
        return eligible.first ?? stored
    }

    /// The selector is only meaningful when the user actually has a choice —
    /// two or more connected providers. With one (or none) the effective
    /// provider is forced, so the row is hidden.
    static func showsSelector(eligible: [AgentProvider]) -> Bool {
        eligible.count >= 2
    }
}
