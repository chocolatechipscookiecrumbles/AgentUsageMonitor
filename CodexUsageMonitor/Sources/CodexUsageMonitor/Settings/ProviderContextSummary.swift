import Foundation

/// Everything one provider's context-rail block renders, already formatted.
/// Provider-neutral so the rail view has no per-provider branching, and pure
/// so the wording is unit-tested rather than living in a view body.
struct ProviderContextSummary: Identifiable, Equatable {
    let provider: AgentProvider
    let isConnected: Bool
    let statusText: String
    let planText: String
    let fiveHourText: String
    let weeklyText: String
    let lastRefreshText: String

    var id: AgentProvider { provider }

    /// Shown for anything the provider did not report. Never `0%` — a missing
    /// figure is not a zero one (capability gate criterion #5).
    static let placeholder = "Unavailable"
    static let connectedStatus = "Connected"
    static let disconnectedStatus = "Disconnected"

    /// Providers with a real read. GitHub Copilot is excluded until its
    /// capability gate passes — no block for a provider we cannot actually
    /// read.
    static func activeProviders(claudeIsUsable: Bool) -> [AgentProvider] {
        claudeIsUsable ? [.codex, .claudeCode] : [.codex]
    }

    static func codex(
        connectionState: AgentConnectionState,
        presentation: QuotaPresentation,
        lastConfirmedAt: Date?,
        valueMode: QuotaValueMode,
        now: Date = .now
    ) -> ProviderContextSummary {
        let connected = connectionState.isConnected
        return ProviderContextSummary(
            provider: .codex,
            isConnected: connected,
            statusText: connected ? connectedStatus : disconnectedStatus,
            planText: planText(connectionState: connectionState, fallback: presentation.planType),
            fiveHourText: percentText(presentation.fiveHour, valueMode: valueMode),
            weeklyText: percentText(presentation.weekly, valueMode: valueMode),
            // Deliberately the *confirmed* time, not the last attempt: a
            // provider whose refreshes are failing must not read as fresh.
            lastRefreshText: lastConfirmedAt.map { RelativeTimeText.text(from: $0, to: now) } ?? placeholder
        )
    }

    static func claude(
        connectionState: ClaudeConnectionState,
        usageState: ClaudeUsageState,
        now: Date = .now
    ) -> ProviderContextSummary {
        let model = usageState.presentation.map { ClaudeUsageDisplayModel(presentation: $0, now: now) }
        let connected = connectionState.isConnected || usageState.isAvailable
        return ProviderContextSummary(
            provider: .claudeCode,
            isConnected: connected,
            statusText: connected ? connectedStatus : disconnectedStatus,
            planText: claudePlanText(connectionState: connectionState, model: model),
            fiveHourText: model?.fiveHour?.usedText ?? placeholder,
            weeklyText: model?.sevenDay?.usedText ?? placeholder,
            lastRefreshText: model?.capturedAtText ?? placeholder
        )
    }

    private static func percentText(_ window: QuotaWindow?, valueMode: QuotaValueMode) -> String {
        guard let window else { return placeholder }
        return "\(valueMode.value(for: window))%"
    }

    private static func planText(connectionState: AgentConnectionState, fallback: String?) -> String {
        if case .connected(let account) = connectionState, let plan = account.planType {
            return plan.capitalized
        }
        return fallback?.capitalized ?? placeholder
    }

    private static func claudePlanText(
        connectionState: ClaudeConnectionState,
        model: ClaudeUsageDisplayModel?
    ) -> String {
        if case .connected(let account) = connectionState, let plan = account.planType {
            return plan.capitalized
        }
        return model?.planText ?? placeholder
    }
}
