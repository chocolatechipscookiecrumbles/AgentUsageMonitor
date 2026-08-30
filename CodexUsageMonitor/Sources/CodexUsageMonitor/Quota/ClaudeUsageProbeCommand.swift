import Foundation

/// Headless diagnostic that exercises the Claude four-tier hierarchy against
/// the real machine (Keychain, statusLine snapshot, cache) before any of it is
/// wired into the UI. Mirrors the Codex `--live-read-once` probe: run once,
/// print JSON, exit. This is a verification tool, not a shipped feature — it
/// lets us confirm each layer resolves as expected on a real account.
///
/// Accepted source order:
///   1. Fresh status-line passive snapshot
///   2. OAuth through Claude Code's credential
///   3. CLI /usage — manual-only, outside the automatic collector
///   4. Cached last-known-good
enum ClaudeUsageProbeCommand {
    static let flag = "--claude-live-read-once"

    /// Diagnostic report — Codable so the output is machine-readable and
    /// carries zero secrets (no token fields exist on any type it touches).
    struct Report: Codable {
        struct Layer: Codable {
            let tier: Int
            let name: String
            let available: Bool
            let detail: String
        }
        struct Coordinator: Codable {
            let delivery: String
            let source: String
            let fiveHourUsedPercent: Double?
            let sevenDayUsedPercent: Double?
            let planHint: String?
            let capturedAt: Date
            let warnings: [String]
        }
        let ranAt: Date
        /// Which OAuth credential method served, if any — never the token.
        let tier1Method: String?
        /// States the interaction policy used by the single collector call.
        let processNote: String
        let layers: [Layer]
        let coordinatorResult: Coordinator
    }

    static func run() async {
        let credentialStore = ClaudeKeychainCredentialStore()
        let oauthSource = ClaudeOAuthUsageSource(credentialStore: credentialStore)
        let statusLineReader = ClaudeRateLimitSnapshotReader()
        let cache = ClaudeUsageCache()
        let passiveSnapshot = statusLineReader.readSnapshot()

        // Exercise the production hierarchy exactly once. Diagnostics are
        // noninteractive, matching scheduled and menu-owned refreshes.
        let collector = ClaudeUsageCollector(oauthSource: oauthSource, statusLineReader: statusLineReader, cache: cache)
        let presentation = await collector.refresh(reason: .menuOpened)
        let snapshot = presentation.snapshot
        let acceptedOAuth = presentation.delivery == .live && snapshot.source == .oauth
        let tier1Method = acceptedOAuth ? "claudeCodeCredentials" : nil

        var layers: [Report.Layer] = []
        if let snap = passiveSnapshot,
           Date.now.timeIntervalSince(snap.capturedAt) <= ClaudeUsageCollector.passiveFastPathFreshness {
            let five = snap.fiveHour.map { String(format: "%.1f%%", $0.usedPercentage) } ?? "—"
            let seven = snap.sevenDay.map { String(format: "%.1f%%", $0.usedPercentage) } ?? "—"
            layers.append(.init(tier: 1, name: "Fresh passive status line", available: true,
                                detail: "5h \(five) · 7d \(seven) · captured \(snap.capturedAt)"))
        } else {
            layers.append(.init(tier: 1, name: "Fresh passive status line", available: false,
                                detail: "no status-line snapshot fresh enough for the fast path"))
        }

        layers.append(.init(
            tier: 2,
            name: "OAuth via Claude Code credential",
            available: acceptedOAuth,
            detail: acceptedOAuth ? "accepted by the collector" : "not accepted by this collector run"
        ))

        // Manual /usage consumes tokens and is intentionally never invoked by
        // this automatic-hierarchy diagnostic.
        layers.append(.init(tier: 3, name: "Manual-only /usage", available: false,
                            detail: "not run — costs tokens and requires a separate explicit action"))

        if let cached = cache.load() {
            layers.append(.init(tier: 4, name: "cached last-known-good", available: true,
                                detail: "source \(cached.snapshot.source.rawValue) · saved \(cached.savedAt)"))
        } else {
            layers.append(.init(tier: 4, name: "cached last-known-good", available: false,
                                detail: "no cache file yet"))
        }

        let s = presentation.snapshot
        let coordinator = Report.Coordinator(
            delivery: String(describing: presentation.delivery),
            source: s.source.rawValue,
            fiveHourUsedPercent: s.fiveHour?.usedPercent,
            sevenDayUsedPercent: s.sevenDay?.usedPercent,
            planHint: s.planHint,
            capturedAt: s.capturedAt,
            warnings: presentation.warnings
        )

        let report = Report(
            ranAt: .now,
            tier1Method: tier1Method,
            processNote: "The production collector ran once with Keychain interaction forbidden; no preliminary credential read was made.",
            layers: layers,
            coordinatorResult: coordinator
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report), let output = String(data: data, encoding: .utf8) {
            print(output)
        }
    }
}
