import Foundation

/// One remaining-quota threshold alert to deliver: a stable dedup key plus copy.
struct QuotaThresholdAlert: Equatable {
    let key: String
    let title: String
    let body: String
}

/// Pure decision for remaining-quota threshold alerts, shared by every provider.
/// The system-touching delivery/dedup stays in `QuotaNotifier`; this half is
/// testable without the notification center.
enum QuotaThresholdEvaluator {
    /// Alerts for a single window, one per enabled threshold the window has
    /// dropped to or below. A window with no reset time is skipped because its
    /// dedup key would not be stable across reads.
    static func alerts(
        provider: AgentProvider,
        window: QuotaWindow?,
        name: String,
        isEnabled: (RemainingQuotaThreshold) -> Bool
    ) -> [QuotaThresholdAlert] {
        guard let window, let resetAt = window.resetAt else { return [] }
        return RemainingQuotaThreshold.allCases.compactMap { threshold in
            guard isEnabled(threshold), window.remainingPercent <= threshold.rawValue else { return nil }
            return QuotaThresholdAlert(
                key: key(provider: provider, name: name, resetAt: resetAt, threshold: threshold),
                title: "\(provider.tabTitle) \(name) limit is low",
                body: "\(window.remainingPercent)% remains before the current limit resets."
            )
        }
    }

    /// Codex keeps its original, provider-less key so already-delivered alerts do
    /// not re-fire now that the key carries a provider dimension. Every other
    /// provider is namespaced.
    static func key(
        provider: AgentProvider,
        name: String,
        resetAt: Date,
        threshold: RemainingQuotaThreshold
    ) -> String {
        let legacy = "quota-\(name)-\(resetAt.timeIntervalSince1970)-\(threshold.rawValue)"
        guard provider != .codex else { return legacy }
        return "quota-\(provider.rawValue)-\(name)-\(resetAt.timeIntervalSince1970)-\(threshold.rawValue)"
    }
}
