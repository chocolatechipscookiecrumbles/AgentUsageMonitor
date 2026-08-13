import Foundation

/// Headless diagnostic that exercises the Claude four-tier hierarchy against
/// the real machine (Keychain, statusLine snapshot, cache) before any of it is
/// wired into the UI. Mirrors the Codex `--live-read-once` probe: run once,
/// print JSON, exit. This is a verification tool, not a shipped feature — it
/// lets us confirm each layer resolves as expected on a real account.
///
/// Layer order (claude_probe_plan four-tier hierarchy):
///   1. OAuth live fetch          (ClaudeOAuthUsageSource)
///   2. CLI /usage probe          — manual-only, outside the automatic collector
///   3. statusLine passive snapshot (ClaudeRateLimitSnapshotReader)
///   4. cached last-known-good    (ClaudeUsageCache)
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
        /// Which tier-1 credential method served, if any — never the token.
        let tier1Method: String?
        /// Why this probe can succeed at the same moment the app degrades.
        /// The probe is a separate process, so it starts with no rate-limit
        /// back-off state and its user-initiated read goes straight to the
        /// Keychain. A disagreement between the two is expected here and is
        /// stated rather than left for the reader to infer.
        let processNote: String
        let layers: [Layer]
        let coordinatorResult: Coordinator
    }

    static func run() async {
        // Claude Code credentials is the working default (browser sign-in is
        // shelved pending a decisive re-test). The recorder reports which
        // method actually served, so a degrade is never invisible.
        let recorder = ClaudeEffectiveMethodRecorder()
        let credentialStore = ClaudeCompositeCredentialStore(
            selectedMethod: .claudeCodeCredentials, recorder: recorder
        )
        let oauthSource = ClaudeOAuthUsageSource(credentialStore: credentialStore)
        let statusLineReader = ClaudeRateLimitSnapshotReader()
        let cache = ClaudeUsageCache()

        var layers: [Report.Layer] = []
        var tier1Method: String?

        // Tier 1: OAuth live fetch. A user-initiated probe may raise a Keychain
        // prompt if it degrades to the Claude Code credentials method — that is
        // acceptable here (the user ran this command).
        do {
            // The user ran this command, so an interactive Keychain read is
            // permitted here — unlike any automatic refresh.
            let snapshot = try await oauthSource.fetch(
                promptPolicy: ClaudeRefreshReason.userInitiated.keychainPromptPolicy
            )
            tier1Method = recorder.effectiveMethod?.rawValue
            let five = snapshot.fiveHour.map { String(format: "%.1f%%", $0.usedPercent) } ?? "—"
            let seven = snapshot.sevenDay.map { String(format: "%.1f%%", $0.usedPercent) } ?? "—"
            let via = recorder.effectiveMethod.map { " · via \($0.displayName)" } ?? ""
            layers.append(.init(tier: 1, name: "OAuth live fetch", available: true,
                                detail: "5h \(five) · 7d \(seven) · plan \(snapshot.planHint ?? "unknown")\(via)"))
        } catch {
            layers.append(.init(tier: 1, name: "OAuth live fetch", available: false,
                                detail: "unavailable: \(error)"))
        }

        // Tier 2: built, but deliberately outside the automatic order —
        // /usage consumes tokens, so it only runs when the user asks.
        layers.append(.init(tier: 2, name: "CLI /usage probe", available: false,
                            detail: "manual only — costs tokens, so never part of an automatic refresh"))

        // Tier 3: statusLine passive snapshot (written by the bundled native bridge).
        if let snap = statusLineReader.readSnapshot() {
            let five = snap.fiveHour.map { String(format: "%.1f%%", $0.usedPercentage) } ?? "—"
            let seven = snap.sevenDay.map { String(format: "%.1f%%", $0.usedPercentage) } ?? "—"
            layers.append(.init(tier: 3, name: "statusLine passive snapshot", available: true,
                                detail: "5h \(five) · 7d \(seven) · captured \(snap.capturedAt)"))
        } else {
            layers.append(.init(tier: 3, name: "statusLine passive snapshot", available: false,
                                detail: "no snapshot at claude-rate-limits.json (bridge not installed or never fired)"))
        }

        // Tier 4: cached last-known-good.
        if let cached = cache.load() {
            layers.append(.init(tier: 4, name: "cached last-known-good", available: true,
                                detail: "source \(cached.snapshot.source.rawValue) · saved \(cached.savedAt)"))
        } else {
            layers.append(.init(tier: 4, name: "cached last-known-good", available: false,
                                detail: "no cache file yet"))
        }

        // Now run the real coordinator and report which layer it settles on.
        let collector = ClaudeUsageCollector(oauthSource: oauthSource, statusLineReader: statusLineReader, cache: cache)
        let presentation = await collector.refresh(reason: .userInitiated)
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
            processNote: "Separate process: no rate-limit back-off state is carried over from the app, "
                + "and this read is user-initiated, so it may reach the Keychain when an app refresh would not.",
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
