import Foundation

enum ClaudeRefreshReason: Sendable {
    case appLaunch
    case scheduled
    case menuOpened
    case userInitiated

    /// Only an explicit user action may raise the Keychain dialog. Every
    /// automatic refresh reads with interaction forbidden, so a scheduled
    /// poll can never interrupt the user with a permission prompt.
    var keychainPromptPolicy: KeychainPromptPolicy {
        switch self {
        case .userInitiated: .userInitiatedOnly
        case .appLaunch, .scheduled, .menuOpened: .never
        }
    }
}

/// Maps the existing, already-shipped statusLine bridge's snapshot type into
/// the shared domain model. Does not modify ClaudeRateLimitSnapshotReader or
/// ClaudeRateLimitSnapshot — this is a pure translation layer.
func adaptStatusLineSnapshot(_ snapshot: ClaudeRateLimitSnapshot) -> ClaudeUsageSnapshot {
    ClaudeUsageSnapshot(
        planHint: nil,
        fiveHour: snapshot.fiveHour.map { ClaudeLimitWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
        sevenDay: snapshot.sevenDay.map { ClaudeLimitWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
        scopedWindows: [],
        extraUsage: nil,
        source: .statusLine,
        capturedAt: snapshot.capturedAt,
        schemaVersion: 1
    )
}

/// Single entry point implementing the four-tier fallback order:
/// OAuth (1) -> CLI /usage probe (2) -> statusLine (3) -> cache (4).
/// Tier 2 is not implemented here (its own dedicated plan), so the runtime
/// order is currently OAuth -> statusLine -> cache. statusLine ranks below a
/// live CLI probe because it is passive and can be stale.
actor ClaudeUsageCollector {
    private let oauthSource: ClaudeOAuthUsageSource
    private let statusLineReader: ClaudeRateLimitSnapshotReader
    private let cache: ClaudeUsageCache

    init(oauthSource: ClaudeOAuthUsageSource, statusLineReader: ClaudeRateLimitSnapshotReader, cache: ClaudeUsageCache) {
        self.oauthSource = oauthSource
        self.statusLineReader = statusLineReader
        self.cache = cache
    }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        if let snapshot = try? await oauthSource.fetch(promptPolicy: reason.keychainPromptPolicy) {
            cache.save(snapshot)
            return ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
        }

        if let statusLineSnapshot = statusLineReader.readSnapshot() {
            let adapted = adaptStatusLineSnapshot(statusLineSnapshot)
            cache.save(adapted)
            return ClaudeUsagePresentation(snapshot: adapted, delivery: .passiveSnapshot, warnings: [])
        }

        if let cached = cache.load() {
            return ClaudeUsagePresentation(snapshot: cached.snapshot, delivery: .cached, warnings: [])
        }

        return ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now, schemaVersion: 1
            ),
            delivery: .cached,
            warnings: ["No Claude usage source is currently available."]
        )
    }
}
