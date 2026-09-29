import XCTest
@testable import CodexUsageMonitor

final class ClaudeCLIUsageProbeParsingTests: XCTestCase {
    // MARK: ANSI

    func testStripsAnsiEscapeSequences() {
        let raw = "\u{1B}[1;36m5-hour limit\u{1B}[0m: \u{1B}[32m44%\u{1B}[0m used"
        XCTAssertEqual(ClaudeCLIUsageProbe.stripANSI(raw), "5-hour limit: 44% used")
    }

    func testStripsCursorAndEraseSequences() {
        let raw = "\u{1B}[2J\u{1B}[H\u{1B}[?25lWeekly limit: 28%\u{1B}[?25h"
        XCTAssertEqual(ClaudeCLIUsageProbe.stripANSI(raw), "Weekly limit: 28%")
    }

    // MARK: parsing

    func testParsesFiveHourAndWeekly() throws {
        let output = """
        Usage
        5-hour limit: 44% used
        Weekly limit: 28% used
        """
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(output))
        XCTAssertEqual(parsed.fiveHour?.usedPercent, 44)
        XCTAssertEqual(parsed.sevenDay?.usedPercent, 28)
        XCTAssertEqual(parsed.source, .cli)
    }

    /// The panel wording is not contractual, so the parser keys off the window
    /// name rather than an exact sentence.
    func testToleratesAlternativeWording() throws {
        let output = """
        Current session (5 hour): 61%
        This week (all models): 72%
        """
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(output))
        XCTAssertEqual(parsed.fiveHour?.usedPercent, 61)
        XCTAssertEqual(parsed.sevenDay?.usedPercent, 72)
    }

    func testParsesDecimalPercentages() throws {
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse("5-hour: 44.6%\nweekly: 28.2%"))
        XCTAssertEqual(parsed.fiveHour?.usedPercent ?? 0, 44.6, accuracy: 0.01)
    }

    func testParsesWithAnsiStillPresent() throws {
        let output = "\u{1B}[1m5-hour limit\u{1B}[0m: \u{1B}[33m44%\u{1B}[0m"
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(output))
        XCTAssertEqual(parsed.fiveHour?.usedPercent, 44)
    }

    func testReturnsNilWhenNoPercentagesPresent() {
        XCTAssertNil(ClaudeCLIUsageProbe.parse("Welcome to Claude Code"))
        XCTAssertNil(ClaudeCLIUsageProbe.parse(""))
    }

    /// A partial read is still useful — but the missing window must stay nil
    /// rather than becoming 0% (capability gate criterion #5).
    func testPartialOutputLeavesMissingWindowNil() throws {
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse("5-hour limit: 44% used"))
        XCTAssertEqual(parsed.fiveHour?.usedPercent, 44)
        XCTAssertNil(parsed.sevenDay, "an unreported window must not be invented as 0%")
    }

    func testIgnoresUnrelatedPercentages() throws {
        let output = """
        Context window: 87% full
        5-hour limit: 44% used
        """
        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(output))
        XCTAssertEqual(parsed.fiveHour?.usedPercent, 44)
        XCTAssertNil(parsed.sevenDay)
    }

    func testParsesObservedResetWordingAndRollsTheYearForward() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 12, day: 31, hour: 12
        )))
        let output = """
        Current session: 20% used · resets Dec 31 at 1pm (America/New_York)
        Weekly limit: 31% used · resets Jan 2 at 3am (America/New_York)
        """

        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(
            output,
            referenceDate: reference,
            timeZone: timeZone
        ))

        XCTAssertEqual(parsed.capturedAt, reference)
        XCTAssertEqual(
            parsed.fiveHour?.resetsAt,
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 13))
        )
        XCTAssertEqual(
            parsed.sevenDay?.resetsAt,
            calendar.date(from: DateComponents(year: 2027, month: 1, day: 2, hour: 3))
        )
    }

    func testParsesISOResetTimestamps() throws {
        let reference = Date(timeIntervalSince1970: 1_798_804_800)
        let output = """
        5-hour limit: 44% used · resets 2027-01-02T08:00:00Z
        Weekly limit: 28% used · resets 2027-01-09T03:00:00.500-05:00
        """

        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(output, referenceDate: reference))

        XCTAssertEqual(parsed.fiveHour?.resetsAt?.timeIntervalSince1970, 1_798_876_800)
        XCTAssertEqual(parsed.sevenDay?.resetsAt?.timeIntervalSince1970, 1_799_481_600.5)
    }

    func testInvalidAndAmbiguousResetsPreservePercentages() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 22, hour: 12
        )))
        let output = """
        Current session: 20% used · resets Sep 31 at 1pm (America/New_York)
        Weekly limit: 31% used · resets Nov 1 at 1:30am (America/New_York)
        """

        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(
            output,
            referenceDate: reference,
            timeZone: timeZone
        ))

        XCTAssertEqual(parsed.fiveHour?.usedPercent, 20)
        XCTAssertNil(parsed.fiveHour?.resetsAt)
        XCTAssertEqual(parsed.sevenDay?.usedPercent, 31)
        XCTAssertNil(parsed.sevenDay?.resetsAt)
    }

    func testPastSameMonthResetDoesNotRollToNextYear() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 22, hour: 12
        )))

        let parsed = try XCTUnwrap(ClaudeCLIUsageProbe.parse(
            "Current session: 20% used · resets Sep 21 at 1pm (America/New_York)",
            referenceDate: reference,
            timeZone: timeZone
        ))

        XCTAssertEqual(parsed.fiveHour?.usedPercent, 20)
        XCTAssertNil(parsed.fiveHour?.resetsAt)
    }
}

final class ClaudeCLIUsageProbeRunTests: XCTestCase {
    func testRunReturnsSnapshotFromInjectedOutput() async throws {
        let probe = ClaudeCLIUsageProbe(runner: { "5-hour limit: 44% used\nWeekly limit: 28% used" })
        let snapshot = try await probe.run()
        XCTAssertEqual(snapshot.fiveHour?.usedPercent, 44)
        XCTAssertEqual(snapshot.source, .cli)
    }

    func testUnparseableOutputThrows() async {
        let probe = ClaudeCLIUsageProbe(runner: { "nothing useful here" })
        do {
            _ = try await probe.run()
            XCTFail("expected a parse failure")
        } catch {
            XCTAssertEqual(error as? ClaudeCLIProbeError, .couldNotParseOutput)
        }
    }

    func testMissingCLIPropagates() async {
        let probe = ClaudeCLIUsageProbe(runner: { throw ClaudeCLIProbeError.missingCLI })
        do {
            _ = try await probe.run()
            XCTFail("expected missingCLI")
        } catch {
            XCTAssertEqual(error as? ClaudeCLIProbeError, .missingCLI)
        }
    }

    /// The consent copy must state the two things the user is agreeing to:
    /// that the CLI runs, and that it costs tokens.
    func testConsentCopyDisclosesCLIAndTokenCost() {
        let copy = ClaudeCLIUsageProbe.consentMessage.lowercased()
        XCTAssertTrue(copy.contains("claude code"), copy)
        XCTAssertTrue(copy.contains("token"), copy)
        XCTAssertFalse(ClaudeCLIUsageProbe.consentTitle.isEmpty)
        XCTAssertFalse(ClaudeCLIUsageProbe.buttonFootnote.isEmpty)
    }

    func testButtonFootnoteWarnsAboutCost() {
        XCTAssertTrue(ClaudeCLIUsageProbe.buttonFootnote.lowercased().contains("token"))
    }
}
