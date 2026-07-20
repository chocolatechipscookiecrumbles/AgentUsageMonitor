import Foundation

enum ClaudeRefreshReason: Sendable {
    case appLaunch
    case scheduled
    case menuOpened
    case userInitiated
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

/// Single entry point implementing the OAuth -> statusLine -> cache order
/// from claude_probe_plan (tier 3, the user-authorized CLI /usage probe, is
/// deliberately not implemented here — see a separate, dedicated plan).
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
        if let snapshot = try? await oauthSource.fetch() {
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
