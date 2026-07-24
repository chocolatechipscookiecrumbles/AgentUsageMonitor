import XCTest
@testable import CodexUsageMonitor

final class MenuBarQuotaBarsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: Value mapping + clamping

    func testRemainingMapsToNormalizedFill() throws {
        let bars = MenuBarQuotaBars(provider: .codex, fiveHourRemaining: 49, weeklyRemaining: 76, freshness: .confirmed)
        XCTAssertEqual(try XCTUnwrap(bars.fiveHour.normalizedRemaining), 0.49, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(bars.weekly.normalizedRemaining), 0.76, accuracy: 0.0001)
    }

    func testBoundaryValues() {
        let bars = MenuBarQuotaBars(provider: .codex, fiveHourRemaining: 100, weeklyRemaining: 0, freshness: .confirmed)
        XCTAssertEqual(bars.fiveHour.normalizedRemaining, 1.0)
        XCTAssertEqual(bars.weekly.normalizedRemaining, 0.0)
    }

    func testMalformedValuesAreClamped() {
        let bars = MenuBarQuotaBars(provider: .codex, fiveHourRemaining: 130, weeklyRemaining: -20, freshness: .confirmed)
        XCTAssertEqual(bars.fiveHour.normalizedRemaining, 1.0, "above 100 clamps to full")
        XCTAssertEqual(bars.weekly.normalizedRemaining, 0.0, "below 0 clamps to empty")
    }

    /// A missing window is `unavailable`, which must be distinguishable from a
    /// real 0% remaining (an empty track vs a genuine near-limit fill).
    func testMissingWindowIsUnavailableNotZero() {
        let bars = MenuBarQuotaBars(provider: .codex, fiveHourRemaining: nil, weeklyRemaining: 0, freshness: .confirmed)
        XCTAssertEqual(bars.fiveHour, .unavailable)
        XCTAssertNil(bars.fiveHour.normalizedRemaining)
        XCTAssertEqual(bars.weekly, .value(0.0))
    }

    func testFullyUnavailableProviderHasNoValueOrFreshness() {
        let bars = MenuBarQuotaBars(provider: .claudeCode, fiveHourRemaining: nil, weeklyRemaining: nil, freshness: .cached)
        XCTAssertFalse(bars.hasAnyValue)
        XCTAssertNil(bars.freshness, "freshness is meaningless with no reading")
    }

    func testPartialAvailabilityKeepsFreshness() {
        let bars = MenuBarQuotaBars(provider: .codex, fiveHourRemaining: 30, weeklyRemaining: nil, freshness: .cached)
        XCTAssertTrue(bars.hasAnyValue)
        XCTAssertEqual(bars.freshness, .cached)
        XCTAssertEqual(bars.weekly, .unavailable)
    }

    // MARK: Claude builder (window eligibility + freshness)

    func testClaudeBuilderDropsExpiredWindow() throws {
        let state = ClaudeUsageState.available(
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: "pro",
                    fiveHour: ClaudeLimitWindow(usedPercent: 90, resetsAt: now.addingTimeInterval(-60)), // expired
                    sevenDay: ClaudeLimitWindow(usedPercent: 24, resetsAt: now.addingTimeInterval(3_600)),
                    scopedWindows: [], extraUsage: nil, source: .oauth, capturedAt: now, schemaVersion: 1
                ),
                delivery: .cached,
                warnings: []
            )
        )

        let bars = MenuBarQuotaBars.claude(usageState: state, now: now)
        XCTAssertEqual(bars.fiveHour, .unavailable, "expired window is not drawn")
        XCTAssertEqual(try XCTUnwrap(bars.weekly.normalizedRemaining), 0.76, accuracy: 0.0001) // 100-24
        XCTAssertEqual(bars.freshness, .cached)
    }

    func testClaudeUnavailableStateProducesEmptyBars() {
        let bars = MenuBarQuotaBars.claude(usageState: .unavailable(reason: "no source"), now: now)
        XCTAssertEqual(bars.fiveHour, .unavailable)
        XCTAssertEqual(bars.weekly, .unavailable)
        XCTAssertNil(bars.freshness)
    }

    // MARK: Ordering / list

    func testProvidersListIsCodexThenClaude() {
        let list = MenuBarQuotaBars.providers(
            codexDisplayState: QuotaDisplayState(mode: .cachedPaused, displayedRecord: nil, lastAttemptAt: now, lastConfirmedAt: nil, pauseReason: .unavailable),
            claudeState: .unavailable(reason: "x"),
            now: now
        )
        XCTAssertEqual(list.map(\.provider), [.codex, .claudeCode])
    }
}
