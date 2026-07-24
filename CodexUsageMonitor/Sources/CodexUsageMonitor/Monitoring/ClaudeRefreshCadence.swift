import Foundation

/// Maps the shared `RefreshMode` setting to Claude's poll cadence.
///
/// The Refresh Preferences setting governs every agent, but one shared *setting*
/// must not mean one shared *network frequency*. Codex's authoritative read is a
/// local app-server read, so it can safely use the full fast range (including the
/// 30s automatic burst). Claude's authoritative read is a networked Anthropic
/// OAuth call, so polling it as aggressively as Codex risks endpoint/rate-limit
/// issues. The networked poll is therefore clamped to a conservative floor
/// regardless of the selected mode; the cheaper local statusLine/cache paths
/// inside each refresh still update as part of the collector's own fallback
/// order.
enum ClaudeRefreshCadence {
    /// Network floor for Claude's OAuth read. Five minutes means at most twelve
    /// reads per hour, which is negligible for a lightweight status GET. The
    /// rate-safety probe (docs/development/claude-usage-endpoint-rate-safety.md)
    /// found the real risk was a missing `User-Agent` header, now sent, plus a
    /// `Retry-After` back-off on 429 in the collector; with those, 5 minutes is
    /// safe. Do not lower it — there is no user benefit and the endpoint 429s
    /// aggressively.
    static let networkFloor: Duration = .seconds(5 * 60)

    /// Claude's steady automatic interval. Claude does not burst on the network
    /// (unlike Codex's local read), so automatic resolves to the floor.
    static let automaticInterval: Duration = .seconds(5 * 60)

    /// The Claude poll interval for the given shared mode, never faster than the
    /// network floor. Fixed modes below the floor (e.g. 90s, 2m) clamp up to it;
    /// modes at or above the floor (5m, 10m) are used as-is.
    static func pollInterval(for mode: RefreshMode) -> Duration {
        let requested = mode.fixedInterval.map { Duration.seconds($0) } ?? automaticInterval
        return max(requested, networkFloor)
    }
}
