import XCTest
@testable import CodexUsageMonitor

private func makePresentation(
    delivery: ClaudeUsageDelivery = .live,
    source: ClaudeUsageSource = .oauth,
    capturedAt: Date = .now,
    fiveHour: (Double, Date?)? = (10, nil),
    sevenDay: (Double, Date?)? = (20, nil),
    planHint: String? = "pro"
) -> ClaudeUsagePresentation {
    ClaudeUsagePresentation(
        snapshot: ClaudeUsageSnapshot(
            planHint: planHint,
            fiveHour: fiveHour.map { ClaudeLimitWindow(usedPercent: $0.0, resetsAt: $0.1) },
            sevenDay: sevenDay.map { ClaudeLimitWindow(usedPercent: $0.0, resetsAt: $0.1) },
            scopedWindows: [],
            extraUsage: nil,
            source: source,
            capturedAt: capturedAt,
            schemaVersion: 1
        ),
        delivery: delivery,
        warnings: []
    )
}

final class ClaudeUsageDisplayModelTests: XCTestCase {
    // MARK: relative capture time

    func testJustNowForRecentCapture() {
        let model = ClaudeUsageDisplayModel(presentation: makePresentation(capturedAt: .now), now: .now)
        XCTAssertEqual(model.capturedAtText, "just now")
    }

    func testMinutesAgo() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(capturedAt: now.addingTimeInterval(-8 * 60)), now: now
        )
        XCTAssertEqual(model.capturedAtText, "8 minutes ago")
    }

    func testSingularMinute() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(capturedAt: now.addingTimeInterval(-60)), now: now
        )
        XCTAssertEqual(model.capturedAtText, "1 minute ago")
    }

    func testHoursAgo() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(capturedAt: now.addingTimeInterval(-3 * 3600)), now: now
        )
        XCTAssertEqual(model.capturedAtText, "3 hours ago")
    }

    func testDaysAgo() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(capturedAt: now.addingTimeInterval(-36 * 3600)), now: now
        )
        XCTAssertEqual(model.capturedAtText, "1 day ago")
    }

    // MARK: source labels (probe plan §9)

    func testLiveOAuthSourceLabel() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(delivery: .live, source: .oauth), now: .now
        )
        XCTAssertEqual(model.sourceLabel, "Claude OAuth")
    }

    func testPassiveStatusLineSourceLabel() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(delivery: .passiveSnapshot, source: .statusLine), now: .now
        )
        XCTAssertEqual(model.sourceLabel, "Claude Code capture")
    }

    /// A cached result must say it is cached while still naming where the data
    /// originally came from.
    func testCachedLabelPreservesOrigin() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(delivery: .cached, source: .oauth), now: .now
        )
        XCTAssertTrue(model.sourceLabel.contains("Cached"), model.sourceLabel)
        XCTAssertTrue(model.sourceLabel.contains("Claude OAuth"), model.sourceLabel)
    }

    func testOnlyLiveDeliveryIsConsideredFresh() {
        XCTAssertTrue(ClaudeUsageDisplayModel(presentation: makePresentation(delivery: .live), now: .now).isLive)
        XCTAssertFalse(ClaudeUsageDisplayModel(presentation: makePresentation(delivery: .cached), now: .now).isLive)
        XCTAssertFalse(
            ClaudeUsageDisplayModel(presentation: makePresentation(delivery: .passiveSnapshot), now: .now).isLive
        )
    }

    func testStaleDeliveryCarriesAnExplicitNotice() {
        let model = ClaudeUsageDisplayModel(presentation: makePresentation(delivery: .cached), now: .now)
        XCTAssertNotNil(model.stalenessNotice)
        XCTAssertNil(ClaudeUsageDisplayModel(presentation: makePresentation(delivery: .live), now: .now).stalenessNotice)
    }

    // MARK: expired windows (probe plan §7)

    func testWindowWhoseResetHasPassedIsMarkedExpired() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(
                capturedAt: now.addingTimeInterval(-7200),
                fiveHour: (90, now.addingTimeInterval(-60))
            ),
            now: now
        )
        XCTAssertTrue(model.fiveHour?.hasReset == true, "a window past its reset must not read as current")
        XCTAssertNotNil(model.fiveHour?.resetNote)
    }

    func testFutureResetIsNotExpired() {
        let now = Date()
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(fiveHour: (10, now.addingTimeInterval(3600))), now: now
        )
        XCTAssertEqual(model.fiveHour?.hasReset, false)
        XCTAssertNil(model.fiveHour?.resetNote)
    }

    // MARK: values and copy

    func testPercentFormatting() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(fiveHour: (26.4, nil), sevenDay: (20, nil)), now: .now
        )
        XCTAssertEqual(model.fiveHour?.usedText, "26%")
        XCTAssertEqual(model.sevenDay?.usedText, "20%")
    }

    func testMissingWindowIsNilRatherThanZero() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(fiveHour: nil, sevenDay: (20, nil)), now: .now
        )
        XCTAssertNil(model.fiveHour, "a missing window must be absent, never rendered as 0%")
        XCTAssertNotNil(model.sevenDay)
    }

    func testPlanHintSurfaced() {
        let model = ClaudeUsageDisplayModel(presentation: makePresentation(planHint: "pro"), now: .now)
        XCTAssertEqual(model.planText, "Pro")
    }

    /// Gate criterion #3: the weekly number's scope must be stated, because it
    /// is shared with Claude chat rather than being Claude Code only.
    func testWeeklyCarriesTheSharedPoolCaveat() {
        XCTAssertTrue(ClaudeUsageDisplayModel.weeklyScopeCaveat.lowercased().contains("shared"))
        XCTAssertFalse(ClaudeUsageDisplayModel.weeklyScopeCaveat.isEmpty)
    }
}
