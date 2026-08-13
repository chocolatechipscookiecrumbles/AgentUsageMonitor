import Foundation

enum ClaudeRefreshReason: Sendable, Equatable {
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
/// Tier 2 is deliberately manual-only and therefore stays outside this automatic
/// collector. The automatic runtime order is OAuth -> statusLine -> cache.
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

    /// A press is allowed through the back-off, because a back-off the user
    /// cannot see or override is indistinguishable from a broken button — the
    /// read never reaches the Keychain, so not even the permission dialog
    /// appears. The allowance is bounded so a held-down button still cannot
    /// compound a 429.
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
        // Why this refresh is not returning a live reading. A refresh that ends
        // without one must say so: a pressed button that changes nothing on
        // screen and explains nothing is itself the defect being fixed here.
        var degradeReason: String?

        switch tierOneAttempt(for: reason) {
        case .suppressed(let notice):
            degradeReason = notice

        case .attempt:
            do {
                let snapshot = try await oauthSource.fetch(promptPolicy: reason.keychainPromptPolicy)
                clearBackoff()
                cache.save(snapshot)
                return ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
            } catch let error as ClaudeOAuthError {
                if case .rateLimited(let retryAfter) = error {
                    oauthBackoffUntil = retryAfter ?? now().addingTimeInterval(Self.defaultRateLimitBackoff)
                }
                degradeReason = Self.explanation(for: error, backoffUntil: oauthBackoffUntil)
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
        let cached = cache.load()?.snapshot

        let warnings = degradeReason.map { [$0] } ?? []

        if let statusLine, cached.map({ statusLine.capturedAt >= $0.capturedAt }) ?? true {
            cache.save(statusLine)
            return ClaudeUsagePresentation(snapshot: statusLine, delivery: .passiveSnapshot, warnings: warnings)
        }

        if let cached {
            return ClaudeUsagePresentation(snapshot: cached, delivery: .cached, warnings: warnings)
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

    private enum TierOneAttempt {
        case attempt
        case suppressed(String)
    }

    /// Decides whether tier 1 runs, and if not, why — in words the UI can show.
    ///
    /// The back-off used to gate every reason equally, so during a 15-minute
    /// window an explicit Refresh silently skipped the network *and* the
    /// Keychain. That is the reported bug: no reading, no dialog, no message,
    /// while the CLI probe — a separate process holding no back-off state —
    /// worked seconds later.
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
        case .credentialAccessDenied:
            return "macOS denied access to the Claude Code credential in your Keychain. "
                + "Reconnect Claude to grant access again."
        case .credentialsNotFound:
            return "No Claude Code credential was found. Connect Claude to read live usage."
        case .insufficientScope:
            return "The stored Claude credential cannot read usage. Reconnect Claude."
        case .unauthorized:
            return "Claude rejected the stored credential. Reconnect Claude."
        case .serverFailure(let statusCode):
            return "Claude's usage service returned an error (\(statusCode)). Showing the last reading."
        case .transportError:
            return "Could not reach Claude's usage service. Showing the last reading."
        case .malformedResponse:
            return "Claude's usage service returned an unexpected response. Showing the last reading."
        }
    }
}
