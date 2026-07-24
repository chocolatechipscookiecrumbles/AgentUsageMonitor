import Foundation

/// A newly-enabled remaining-quota threshold awaiting a confirmation notification.
struct PendingThresholdConfirmation: Hashable {
    let provider: AgentProvider
    let threshold: RemainingQuotaThreshold
}

/// Builds the confirmation copy shown after a user turns on one or more quota
/// thresholds. Several toggles made in quick succession are summarized into one
/// message; the debounce that groups them lives in `QuotaViewModel`.
enum ThresholdConfirmationMessage {
    /// e.g. "Will warn you when Claude reaches 25%." or
    /// "Will warn you when Codex reaches 25% and 10% and Claude reaches 5%."
    static func body(for pending: [PendingThresholdConfirmation]) -> String? {
        guard !pending.isEmpty else { return nil }
        let byProvider = Dictionary(grouping: pending) { $0.provider }
        // Stable provider order so the sentence reads the same each time.
        let clauses = AppSettings.quotaThresholdProviders.compactMap { provider -> String? in
            guard let items = byProvider[provider], !items.isEmpty else { return nil }
            let percents = Set(items.map(\.threshold.rawValue))
                .sorted(by: >)
                .map { "\($0)%" }
            return "\(provider.tabTitle) reaches \(list(percents))"
        }
        guard !clauses.isEmpty else { return nil }
        return "Will warn you when \(list(clauses))."
    }

    /// Natural-language join: "a", "a and b", "a, b, and c".
    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return "\(items.dropLast().joined(separator: ", ")), and \(items[items.count - 1])"
        }
    }
}
