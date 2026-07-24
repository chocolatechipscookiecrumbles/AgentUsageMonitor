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
    /// Conservative network floor for Claude's OAuth read, pending the dedicated
    /// rate-safety probe (plan Workstream G, Step 1b). Five minutes means at most
    /// twelve networked reads per hour, which stays well clear of any reasonable
    /// endpoint limit. Adjust only with probe evidence, never below what the
    /// endpoint tolerates.
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
