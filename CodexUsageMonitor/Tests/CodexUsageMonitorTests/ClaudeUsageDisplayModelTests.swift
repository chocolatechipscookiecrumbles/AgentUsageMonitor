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

    // MARK: extra usage (Anthropic's pay-as-you-go credits)

    private func withExtraUsage(_ extra: ClaudeExtraUsage?) -> ClaudeUsagePresentation {
        let base = makePresentation()
        return ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: base.snapshot.planHint,
                fiveHour: base.snapshot.fiveHour,
                sevenDay: base.snapshot.sevenDay,
                scopedWindows: [],
                extraUsage: extra,
                source: .oauth,
                capturedAt: base.snapshot.capturedAt,
                schemaVersion: 1
            ),
            delivery: .live,
            warnings: []
        )
    }

    func testCreditsAreAbsentWhenTheEndpointOmitsThem() {
        let model = ClaudeUsageDisplayModel(presentation: withExtraUsage(nil), now: .now)
        XCTAssertNil(model.creditsUsedText)
    }

    /// The live shape on a Pro account: enabled, nothing spent, no cap
    /// returned. "0 spent" must not be presented as "0 remaining".
    func testSpendWithNoCapIsJustTheAmount() {
        let model = ClaudeUsageDisplayModel(
            presentation: withExtraUsage(
                ClaudeExtraUsage(isEnabled: true, monthlyLimit: nil, usedCredits: 0, currencyCode: "USD")
            ),
            now: .now
        )

        let value = model.creditsUsedText ?? ""
        XCTAssertTrue(value.contains("0.00"), value)
        XCTAssertFalse(
            value.lowercased().contains("remaining"),
            "spend must never be phrased as a remaining balance"
        )
    }

    func testSpendAgainstACapShowsBoth() {
        let model = ClaudeUsageDisplayModel(
            presentation: withExtraUsage(
                ClaudeExtraUsage(isEnabled: true, monthlyLimit: 50, usedCredits: 12.5, currencyCode: "USD")
            ),
            now: .now
        )

        let value = model.creditsUsedText ?? ""
        XCTAssertTrue(value.contains("12.50"), value)
        XCTAssertTrue(value.contains("50.00"), value)
    }

    func testDisabledExtraUsageIsReportedAsOff() {
        let model = ClaudeUsageDisplayModel(
            presentation: withExtraUsage(
                ClaudeExtraUsage(isEnabled: false, monthlyLimit: nil, usedCredits: nil, currencyCode: nil)
            ),
            now: .now
        )

        XCTAssertEqual(model.creditsUsedText, "Off")
    }

    func testNonUSDCurrencyIsHonoured() {
        let model = ClaudeUsageDisplayModel(
            presentation: withExtraUsage(
                ClaudeExtraUsage(isEnabled: true, monthlyLimit: nil, usedCredits: 3, currencyCode: "EUR")
            ),
            now: .now
        )

        let value = model.creditsUsedText ?? ""
        XCTAssertTrue(value.contains("3"), value)
        XCTAssertFalse(value.contains("US$"), "must not render a USD symbol for a EUR amount")
    }

    /// The view passes usedPercent straight through, so it must be the raw
    /// number rather than something parsed back out of the display string.
    func testWindowCarriesTheRawPercent() {
        let model = ClaudeUsageDisplayModel(
            presentation: makePresentation(fiveHour: (26.4, nil)), now: .now
        )
        XCTAssertEqual(model.fiveHour?.usedPercent, 26)
        XCTAssertEqual(model.fiveHour?.usedText, "26%")
    }

    /// Anthropic reports no remaining balance, so the label must say "used".
    func testCreditsLabelSaysUsedNotRemaining() {
        XCTAssertTrue(ClaudeUsageDisplayModel.creditsUsedLabel.lowercased().contains("used"))
        XCTAssertFalse(ClaudeUsageDisplayModel.creditsUsedLabel.lowercased().contains("remaining"))
    }

    /// Gate criterion #3: the weekly number's scope must be stated, because it
    /// is shared with Claude chat rather than being Claude Code only.
    func testWeeklyCarriesTheSharedPoolCaveat() {
        XCTAssertTrue(ClaudeUsageDisplayModel.weeklyScopeCaveat.lowercased().contains("shared"))
        XCTAssertFalse(ClaudeUsageDisplayModel.weeklyScopeCaveat.isEmpty)
    }
}

/// The note costs a line, so it may only appear where it is actually true.
final class ClaudeFiveHourSessionNoteTests: XCTestCase {
    func testShownWhenConnectedWithNoWindowRunning() {
        XCTAssertTrue(
            ClaudeUsageDisplayModel.showsFiveHourSessionNote(isConnected: true, hasFiveHourWindow: false)
        )
    }

    func testHiddenOnceAWindowIsRunning() {
        XCTAssertFalse(
            ClaudeUsageDisplayModel.showsFiveHourSessionNote(isConnected: true, hasFiveHourWindow: true),
            "the reset row already says everything needed"
        )
    }

    /// With no connection, a missing window means "we could not read", not
    /// "your session has not started".
    func testHiddenWhenDisconnected() {
        XCTAssertFalse(
            ClaudeUsageDisplayModel.showsFiveHourSessionNote(isConnected: false, hasFiveHourWindow: false)
        )
        XCTAssertFalse(
            ClaudeUsageDisplayModel.showsFiveHourSessionNote(isConnected: false, hasFiveHourWindow: true)
        )
    }
}
