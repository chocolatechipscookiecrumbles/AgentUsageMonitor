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

        It may consume tokens from your Claude quota. Automatic refreshes never \
        run it.

        Use it when you want to force a fresh reading and the usual sources \
        are unavailable.
        """

    static let buttonFootnote =
        "Runs claude -p /usage once. It may consume tokens from your Claude quota; automatic refresh never runs it."

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
    static func parse(
        _ rawOutput: String,
        referenceDate: Date = .now,
        timeZone: TimeZone = .current
    ) -> ClaudeUsageSnapshot? {
        let text = stripANSI(rawOutput)
        var fiveHour: ClaudeLimitWindow?
        var sevenDay: ClaudeLimitWindow?

        for line in text.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            guard let percent = firstPercent(in: String(line)) else { continue }
            let window = ClaudeLimitWindow(
                usedPercent: percent,
                resetsAt: resetDate(in: String(line), referenceDate: referenceDate, timeZone: timeZone)
            )
            // "context window: 87% full" is not a rate limit; only lines
            // naming a usage window count.
            if fiveHour == nil, lower.contains("5-hour") || lower.contains("5 hour")
                || lower.contains("five hour") || lower.contains("session") {
                fiveHour = window
            } else if sevenDay == nil, lower.contains("week") || lower.contains("7-day")
                || lower.contains("7 day") || lower.contains("seven day") {
                sevenDay = window
            }
        }

        guard fiveHour != nil || sevenDay != nil else { return nil }
        return ClaudeUsageSnapshot(
            planHint: nil,
            // A window the CLI did not report stays nil — never 0%.
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            scopedWindows: [],
            extraUsage: nil,
            source: .cli,
            capturedAt: referenceDate,
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

    private static func resetDate(in line: String, referenceDate: Date, timeZone: TimeZone) -> Date? {
        guard let marker = line.range(of: "\\bresets?\\b", options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let resetText = line[marker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if let isoRange = resetText.range(
            of: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\\.[0-9]+)?(?:Z|[+-][0-9]{2}:?[0-9]{2})",
            options: .regularExpression
        ) {
            let value = String(resetText[isoRange])
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return plausibleReset(date, referenceDate: referenceDate)
            }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: value)
                .flatMap { plausibleReset($0, referenceDate: referenceDate) }
        }
        return localResetDate(resetText, referenceDate: referenceDate, fallbackTimeZone: timeZone)
            .flatMap { plausibleReset($0, referenceDate: referenceDate) }
    }

    private static func localResetDate(
        _ rawValue: String,
        referenceDate: Date,
        fallbackTimeZone: TimeZone
    ) -> Date? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeZone: TimeZone
        if value.hasSuffix(")") {
            guard let open = value.lastIndex(of: "(") else { return nil }
            let identifier = value[value.index(after: open)..<value.index(before: value.endIndex)]
            guard let parsed = TimeZone(identifier: String(identifier)) else { return nil }
            timeZone = parsed
            value = String(value[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            timeZone = fallbackTimeZone
        }

        guard let at = value.range(of: " at ", options: .caseInsensitive) else { return nil }
        let dateParts = value[..<at.lowerBound].split(whereSeparator: \.isWhitespace)
        guard dateParts.count == 2,
              let month = monthNumber(String(dateParts[0])),
              let day = Int(dateParts[1]) else { return nil }

        let clock = value[at.upperBound...]
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let isPM = clock.hasSuffix("pm")
        guard isPM || clock.hasSuffix("am") else { return nil }
        let digits = clock.dropLast(2).split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(digits.count),
              let rawHour = Int(digits[0]), (1...12).contains(rawHour),
              let minute = digits.count == 2 ? Int(digits[1]) : 0,
              (0...59).contains(minute) else { return nil }
        let hour = rawHour % 12 + (isPM ? 12 : 0)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.component(.year, from: referenceDate)
        guard let thisYear = unambiguousDate(
            year: year, month: month, day: day, hour: hour, minute: minute, calendar: calendar
        ) else { return nil }
        if thisYear > referenceDate { return thisYear }
        return unambiguousDate(
            year: year + 1, month: month, day: day, hour: hour, minute: minute, calendar: calendar
        )
    }

    private static func unambiguousDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                == DateComponents(year: year, month: month, day: day, hour: hour, minute: minute) else {
            return nil
        }
        let localComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        for offset in stride(from: -7_200, through: 7_200, by: 900) where offset != 0 {
            if calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date.addingTimeInterval(TimeInterval(offset))
            ) == localComponents {
                return nil
            }
        }
        return date
    }

    private static func monthNumber(_ name: String) -> Int? {
        switch name.lowercased().prefix(3) {
        case "jan": 1
        case "feb": 2
        case "mar": 3
        case "apr": 4
        case "may": 5
        case "jun": 6
        case "jul": 7
        case "aug": 8
        case "sep": 9
        case "oct": 10
        case "nov": 11
        case "dec": 12
        default: nil
        }
    }

    private static func plausibleReset(_ date: Date, referenceDate: Date) -> Date? {
        guard date > referenceDate,
              date <= referenceDate.addingTimeInterval(8 * 24 * 60 * 60) else { return nil }
        return date
    }

    private static func runClaudeUsage() throws -> String {
        guard let executable = ClaudeExecutableLocator().locate() else {
            throw ClaudeCLIProbeError.missingCLI
        }
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
