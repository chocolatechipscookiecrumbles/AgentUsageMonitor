import Foundation

enum ClaudeRefreshReason: Sendable, Equatable {
    case appLaunch
    case scheduled
    case menuOpened
    case userInitiated
    case credentialConnection

    /// Only the explicit Connect flow may raise the Keychain dialog. Ordinary
    /// Refresh remains user-initiated for back-off and coalescing purposes, but
    /// reads with interaction forbidden like every automatic refresh.
    var keychainPromptPolicy: KeychainPromptPolicy {
        switch self {
        case .credentialConnection: .userInitiatedOnly
        case .appLaunch, .scheduled, .menuOpened, .userInitiated: .never
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

/// Single entry point for automatic Claude usage collection. A very recent
/// status-line capture is served before constructing any credential read;
/// otherwise OAuth supplies the authoritative reading, followed by the best
/// local snapshot or cache. `/usage` remains an explicit recovery action.
actor ClaudeUsageCollector {
    private let oauthSource: ClaudeOAuthUsageSource
    private let statusLineReader: ClaudeRateLimitSnapshotReader
    private let cache: ClaudeUsageCache
    private let now: @Sendable () -> Date
    /// When the endpoint returns 429, skip the networked OAuth read until this
    /// time and serve local sources. `/api/oauth/usage` rate-limits aggressively
    /// and does not recover if hammered, so hitting it again during a back-off
    /// only compounds the limit.
    private var oauthBackoffUntil: Date?
    /// Used when a 429 arrives with no `Retry-After` header.
    private static let defaultRateLimitBackoff: TimeInterval = 15 * 60
    /// Status-line data arrives immediately after a Claude response. Within
    /// this short window it is fresher than another network read and lets the
    /// app avoid all credential access.
    static let passiveFastPathFreshness = ClaudeUsagePresentation.passiveFreshness

    /// A press is allowed through the back-off, because a back-off the user
    /// cannot see or override is indistinguishable from a broken button. The
    /// allowance is bounded so a held-down button still cannot compound a 429;
    /// it does not change the noninteractive Keychain policy.
    private var lastBypassAt: Date?
    private var bypassCount = 0
    private static let minimumBypassInterval: TimeInterval = 60
    private static let maximumBypassesPerWindow = 5

    init(
        oauthSource: ClaudeOAuthUsageSource,
        statusLineReader: ClaudeRateLimitSnapshotReader,
        cache: ClaudeUsageCache,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.oauthSource = oauthSource
        self.statusLineReader = statusLineReader
        self.cache = cache
        self.now = now
    }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        if let passive = freshPassiveSnapshot() {
            saveIfNotCancelled(passive)
            return ClaudeUsagePresentation(snapshot: passive, delivery: .passiveSnapshot, warnings: [])
        }

        // Why this refresh is not returning a live reading. A refresh that ends
        // without one must say so: a pressed button that changes nothing on
        // screen and explains nothing is itself the defect being fixed here.
        var degradeReason: String?
        var freshFinancial: ClaudeUsageSnapshot?

        switch tierOneAttempt(for: reason) {
        case .suppressed(let notice):
            degradeReason = notice

        case .attempt:
            do {
                let observed = try await oauthSource.fetch(promptPolicy: .never)
                guard observed.hasQuotaWindows || observed.extraUsage != nil else {
                    throw ClaudeOAuthError.malformedResponse
                }
                clearBackoff()
                if !observed.hasQuotaWindows {
                    // Save the independent financial observation, then let the
                    // normal local-source ranking choose passive versus cache.
                    var financial = observed
                    financial.extraUsageObservedAt = observed.capturedAt
                    freshFinancial = financial
                    saveIfNotCancelled(financial)
                    degradeReason = "Claude updated usage-credit spending but did not report quota."
                } else {
                    let snapshot = observed.retainingExtraUsage(from: cache.load()?.snapshot)
                    saveIfNotCancelled(snapshot)
                    return ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
                }
            } catch let error as ClaudeOAuthError {
                if case .rateLimited(let retryAfter) = error {
                    oauthBackoffUntil = retryAfter ?? now().addingTimeInterval(Self.defaultRateLimitBackoff)
                }
                if degradeReason == nil {
                    degradeReason = Self.explanation(for: error, backoffUntil: oauthBackoffUntil)
                }
            } catch {
                degradeReason = "Claude usage could not be read just now."
            }
        }

        // Tier 3 outranks tier 4 because a statusLine capture is *normally*
        // fresher than the cache. That assumption fails when Claude Code has
        // not run for a while: a days-old capture would otherwise be shown in
        // preference to a recent OAuth read we already hold. Rank the two by
        // capture time so the user always sees the best reading available.
        let statusLine = statusLineReader.readSnapshot().map(adaptStatusLineSnapshot)
            .flatMap { $0.hasQuotaWindows ? $0 : nil }
        let cachedSnapshot = cache.load()?.snapshot
        let cached = cachedSnapshot.flatMap { $0.hasQuotaWindows ? $0 : nil }

        let warnings = degradeReason.map { [$0] } ?? []

        if let statusLine, cached.map({ statusLine.capturedAt >= $0.capturedAt }) ?? true {
            let statusLine = statusLine.retainingExtraUsage(from: cachedSnapshot)
                .retainingExtraUsage(from: freshFinancial)
            saveIfNotCancelled(statusLine)
            return ClaudeUsagePresentation(
                snapshot: statusLine,
                delivery: .passiveSnapshot,
                warnings: warnings
            )
        }

        if let cachedSnapshot, cachedSnapshot.hasQuotaWindows || cachedSnapshot.extraUsage != nil {
            let snapshot = cachedSnapshot.retainingExtraUsage(from: freshFinancial)
            return ClaudeUsagePresentation(
                snapshot: snapshot,
                delivery: .cached,
                warnings: warnings
            )
        }

        if let freshFinancial {
            return ClaudeUsagePresentation(
                snapshot: freshFinancial,
                delivery: .cached,
                warnings: warnings
            )
        }

        return ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now, schemaVersion: 1
            ),
            delivery: .cached,
            warnings: [degradeReason ?? "No Claude usage source is currently available."]
        )
    }

    private func saveIfNotCancelled(_ snapshot: ClaudeUsageSnapshot) {
        guard !Task.isCancelled else { return }
        cache.save(snapshot)
    }

    private func freshPassiveSnapshot() -> ClaudeUsageSnapshot? {
        guard let snapshot = statusLineReader.readSnapshot().map(adaptStatusLineSnapshot),
              snapshot.hasQuotaWindows,
              (0...Self.passiveFastPathFreshness).contains(now().timeIntervalSince(snapshot.capturedAt)) else {
            return nil
        }
        return snapshot.retainingExtraUsage(from: cache.load()?.snapshot)
    }

    private enum TierOneAttempt {
        case attempt
        case suppressed(String)
    }

    /// Decides whether tier 1 runs, and if not, why — in words the UI can show.
    ///
    /// The back-off used to gate every reason equally, so during a 15-minute
    /// window an explicit Refresh silently skipped the network and credential
    /// read. That is the reported bug: no reading and no message, while the CLI
    /// probe — a separate process holding no back-off state — worked seconds
    /// later.
    private func tierOneAttempt(for reason: ClaudeRefreshReason) -> TierOneAttempt {
        guard let until = oauthBackoffUntil, now() < until else {
            if oauthBackoffUntil != nil { clearBackoff() }
            return .attempt
        }
        // An automatic read must never re-enter the endpoint during a back-off.
        guard reason == .userInitiated else {
            return .suppressed(Self.rateLimitNotice(until: until))
        }
        guard bypassCount < Self.maximumBypassesPerWindow else {
            return .suppressed(Self.rateLimitNotice(until: until))
        }
        if let lastBypassAt, now().timeIntervalSince(lastBypassAt) < Self.minimumBypassInterval {
            return .suppressed(Self.rateLimitNotice(until: until))
        }
        lastBypassAt = now()
        bypassCount += 1
        return .attempt
    }

    private func clearBackoff() {
        oauthBackoffUntil = nil
        lastBypassAt = nil
        bypassCount = 0
    }

    private static func rateLimitNotice(until: Date) -> String {
        "Anthropic is rate-limiting usage reads until \(shortTime(until)). Showing the last reading."
    }

    private static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// One specific sentence per failure, so a degraded refresh names its cause
    /// instead of reporting a generic outage.
    private static func explanation(for error: ClaudeOAuthError, backoffUntil: Date?) -> String {
        switch error {
        case .rateLimited:
            return backoffUntil.map(rateLimitNotice(until:))
                ?? "Anthropic is rate-limiting usage reads. Showing the last reading."
        case .credentialUnavailable:
            return "Live fallback unavailable. Claude Code’s credential could not be read silently."
        case .insufficientScope:
            return "Live fallback unavailable. The Claude Code credential cannot read usage."
        case .unauthorized:
            return "Live fallback unavailable. Claude Code’s credential was rejected; use Claude Code to renew it."
        case .serverFailure(let statusCode):
            return "Claude's usage service returned an error (\(statusCode)). Showing the last reading."
        case .transportError:
            return "Could not reach Claude's usage service. Showing the last reading."
        case .malformedResponse:
            return "Claude's usage service returned an unexpected response. Showing the last reading."
        }
    }

}
