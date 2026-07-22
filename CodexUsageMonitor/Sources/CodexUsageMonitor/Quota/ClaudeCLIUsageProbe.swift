import Foundation

enum ClaudeCLIProbeError: Error, Equatable {
    case missingCLI
    case commandFailed
    case couldNotParseOutput
}

/// Tier 2 — reads usage by asking the Claude Code CLI directly.
///
/// **Manual only, never automatic.** Anthropic documents that `/usage`
/// generates requests which consume tokens ("typically under $0.04 per
/// session"), so running it on a schedule would spend the user's quota in
/// order to measure their quota. It is therefore not wired into
/// `ClaudeUsageCollector`'s automatic order: it exists solely behind an
/// explicit, consented button, per `claude_probe_plan` §6.
///
/// When OAuth (tier 1) is working this adds nothing — it is for forcing a
/// fresh reading when OAuth is unavailable but the CLI is signed in.
actor ClaudeCLIUsageProbe {
    static let consentTitle = "Read usage with the Claude Code CLI?"

    static let consentMessage = """
        This runs the Claude Code CLI on your machine and asks it for your \
        current usage.

        Anthropic charges a small number of tokens for this check — typically \
        well under $0.04 — which counts against the same quota it reports. \
        Your regular background refreshes never do this.

        Use it when you want to force a fresh reading and the usual sources \
        are unavailable.
        """

    static let buttonFootnote =
        "Runs the Claude Code CLI. Costs a few tokens against your quota, unlike the automatic refreshes."

    private let runner: @Sendable () throws -> String

    init(runner: (@Sendable () throws -> String)? = nil) {
        self.runner = runner ?? { try Self.runClaudeUsage() }
    }

    func run() throws -> ClaudeUsageSnapshot {
        let output = try runner()
        guard let snapshot = Self.parse(output) else {
            throw ClaudeCLIProbeError.couldNotParseOutput
        }
        return snapshot
    }

    /// The `/usage` panel's wording is not a documented contract, so the
    /// parser keys off the window name and takes the first percentage on that
    /// line rather than matching a fixed sentence.
    static func parse(_ rawOutput: String) -> ClaudeUsageSnapshot? {
        let text = stripANSI(rawOutput)
        var fiveHour: Double?
        var sevenDay: Double?

        for line in text.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            guard let percent = firstPercent(in: String(line)) else { continue }
            // "context window: 87% full" is not a rate limit; only lines
            // naming a usage window count.
            if fiveHour == nil, lower.contains("5-hour") || lower.contains("5 hour")
                || lower.contains("five hour") || lower.contains("session") {
                fiveHour = percent
            } else if sevenDay == nil, lower.contains("week") || lower.contains("7-day")
                || lower.contains("7 day") || lower.contains("seven day") {
                sevenDay = percent
            }
        }

        guard fiveHour != nil || sevenDay != nil else { return nil }
        return ClaudeUsageSnapshot(
            planHint: nil,
            // A window the CLI did not report stays nil — never 0%.
            fiveHour: fiveHour.map { ClaudeLimitWindow(usedPercent: $0, resetsAt: nil) },
            sevenDay: sevenDay.map { ClaudeLimitWindow(usedPercent: $0, resetsAt: nil) },
            scopedWindows: [],
            extraUsage: nil,
            source: .cli,
            capturedAt: .now,
            schemaVersion: 1
        )
    }

    static func stripANSI(_ text: String) -> String {
        // CSI sequences (colour, cursor moves, erases) plus the private-mode
        // forms the TUI uses to hide/show the cursor.
        let pattern = "\u{1B}\\[[0-9;?]*[ -/]*[@-~]"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func firstPercent(in line: String) -> Double? {
        guard let range = line.range(of: "[0-9]+(\\.[0-9]+)?(?=%)", options: .regularExpression) else {
            return nil
        }
        return Double(line[range])
    }

    private static func runClaudeUsage() throws -> String {
        let executable = try ClaudeExecutableLocator().locate()
        let process = Process()
        process.executableURL = executable
        // Print mode so the session is non-interactive and exits on its own.
        process.arguments = ["-p", "/usage"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw ClaudeCLIProbeError.missingCLI
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ClaudeCLIProbeError.commandFailed }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
