import XCTest
@testable import CodexUsageMonitor

/// The week view aggregates the *same* reconciled requests as the day view over
/// a wider window, so the defects worth covering are the ones that would let it
/// report a number local records do not support: a rolling seven days instead
/// of the calendar week, and day boundaries that drift once a daylight-saving
/// transition falls inside the range.
final class TokenMonitorRangeAggregationTests: XCTestCase {
    /// Sunday-first, so the 2026 US spring-forward transition (Sunday March 8,
    /// 02:00) lands on the *first* day of the week under test and every later
    /// bucket in that week is downstream of it.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 1
        return calendar
    }()

    // MARK: - The calendar week, not a rolling seven days

    func testWeekRangeExcludesRequestsFromThePreviousWeek() throws {
        // Thursday of the week beginning Sunday, March 8.
        let now = try date(year: 2026, month: 3, day: 12, hour: 12)
        let thisWeek = request(id: "this-week", at: try date(year: 2026, month: 3, day: 9, hour: 9), tokens: 300)
        // Saturday, March 7: one day earlier, but the previous calendar week.
        let lastWeek = request(id: "last-week", at: try date(year: 2026, month: 3, day: 7, hour: 9), tokens: 900)

        let snapshot = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex,
                requests: [lastWeek, thisWeek],
                range: .week,
                generatedAt: now,
                calendar: calendar
            )
        )

        XCTAssertEqual(snapshot.rangeTokens.totalTokens, 300)
        XCTAssertEqual(snapshot.requestCount, 1)
        XCTAssertEqual(snapshot.rangeStartedAt, try date(year: 2026, month: 3, day: 8, hour: 0))
        XCTAssertFalse(
            snapshot.buckets.contains { $0.totalTokens == 900 },
            "a request from the previous calendar week must not fill a bucket in this one"
        )
    }

    /// Out-of-range requests are excluded from the totals but must still be
    /// reachable as Last Request, or a quiet week would read as if nothing was
    /// ever observed.
    func testLastRequestSurvivesOutsideTheRange() throws {
        let now = try date(year: 2026, month: 3, day: 12, hour: 12)
        let older = request(id: "older", at: try date(year: 2026, month: 3, day: 2, hour: 9), tokens: 700)

        let snapshot = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex,
                requests: [older],
                range: .week,
                generatedAt: now,
                calendar: calendar
            )
        )

        XCTAssertEqual(snapshot.rangeTokens.totalTokens, 0)
        XCTAssertEqual(snapshot.lastRequest?.id, "older")
    }

    // MARK: - Bucket boundaries

    /// Stepping by a fixed 86,400 seconds instead of by a calendar day would
    /// leave every bucket after the spring-forward transition starting at 01:00
    /// local, and a request logged between midnight and 01:00 would fall into
    /// the previous day's bar.
    func testWeekBucketsStayAlignedToLocalDaysAcrossADaylightSavingChange() throws {
        let now = try date(year: 2026, month: 3, day: 12, hour: 12)
        let earlyMorning = try date(year: 2026, month: 3, day: 10, hour: 0, minute: 30)
        let logged = request(id: "early", at: earlyMorning, tokens: 500)

        let snapshot = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex,
                requests: [logged],
                range: .week,
                generatedAt: now,
                calendar: calendar
            )
        )

        // Sunday through Thursday: one bar per elapsed day, none for the days
        // the week has not reached.
        XCTAssertEqual(snapshot.buckets.count, 5)
        for bucket in snapshot.buckets {
            XCTAssertEqual(
                bucket.startedAt,
                calendar.startOfDay(for: bucket.startedAt),
                "a week bucket must begin at a local midnight"
            )
            XCTAssertEqual(bucket.endedAt, calendar.startOfDay(for: bucket.endedAt))
        }

        let filled = try XCTUnwrap(snapshot.buckets.first { $0.totalTokens > 0 })
        XCTAssertEqual(filled.startedAt, calendar.startOfDay(for: earlyMorning))
        XCTAssertEqual(filled.totalTokens, 500)
    }

    func testDayRangeKeepsThirtyMinuteBuckets() throws {
        let now = try date(year: 2026, month: 3, day: 12, hour: 2)
        let logged = request(id: "one", at: try date(year: 2026, month: 3, day: 12, hour: 1, minute: 40), tokens: 250)

        let snapshot = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex,
                requests: [logged],
                range: .day,
                generatedAt: now,
                calendar: calendar
            )
        )

        // Midnight through the interval containing 02:00: five half hours.
        XCTAssertEqual(snapshot.buckets.count, 5)
        for bucket in snapshot.buckets {
            XCTAssertEqual(bucket.endedAt.timeIntervalSince(bucket.startedAt), 1800)
        }
        let filled = try XCTUnwrap(snapshot.buckets.first { $0.totalTokens > 0 })
        XCTAssertEqual(filled.startedAt, try date(year: 2026, month: 3, day: 12, hour: 1, minute: 30))
    }

    /// Both windows read the same requests, so the week can never total less
    /// than the day inside it.
    func testWeekTotalIncludesTheDayTotal() throws {
        let now = try date(year: 2026, month: 3, day: 12, hour: 12)
        let requests = [
            request(id: "monday", at: try date(year: 2026, month: 3, day: 9, hour: 9), tokens: 400),
            request(id: "today", at: try date(year: 2026, month: 3, day: 12, hour: 9), tokens: 600),
        ]

        let day = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex, requests: requests, range: .day, generatedAt: now, calendar: calendar
            )
        )
        let week = try XCTUnwrap(
            LocalActivityAggregation.snapshot(
                provider: .codex, requests: requests, range: .week, generatedAt: now, calendar: calendar
            )
        )

        XCTAssertEqual(day.rangeTokens.totalTokens, 600)
        XCTAssertEqual(week.rangeTokens.totalTokens, 1000)
    }

    /// An empty window is an observed zero, and it has to keep saying which
    /// window it observed.
    func testEmptyWeekReportsTheWeekRange() throws {
        let now = try date(year: 2026, month: 3, day: 12, hour: 12)

        let state = LocalActivityAggregation.state(
            provider: .codex,
            requests: [],
            range: .week,
            generatedAt: now,
            calendar: calendar
        )

        guard case .noActivity(let range, let startedAt, let lastRequest) = state else {
            return XCTFail("expected no activity, got \(String(describing: state))")
        }
        XCTAssertEqual(range, .week)
        XCTAssertEqual(startedAt, try date(year: 2026, month: 3, day: 8, hour: 0))
        XCTAssertNil(lastRequest)
    }

    // MARK: - Helpers

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func request(id: String, at occurredAt: Date, tokens: Int64) -> LocalActivityRequest {
        LocalActivityRequest(
            id: id,
            provider: .codex,
            occurredAt: occurredAt,
            modelID: "gpt-5",
            tokens: LocalActivityTokenBreakdown(
                provider: .codex,
                inputTokens: tokens,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0
            )!
        )
    }
}

/// The stored preference behind the card's window.
@MainActor
final class TokenMonitorRangePersistenceTests: XCTestCase {
    func testRangeDefaultsToDayForEveryProvider() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            for provider in AgentProvider.allCases {
                XCTAssertEqual(settings.tokenMonitorRange(for: provider), .day)
            }
        }
    }

    func testRangeIsPerProviderAndSurvivesRelaunch() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            settings.setTokenMonitorRange(.week, for: .codex)

            let reloaded = AppSettings(defaults: defaults)
            XCTAssertEqual(reloaded.tokenMonitorRange(for: .codex), .week)
            XCTAssertEqual(
                reloaded.tokenMonitorRange(for: .claudeCode),
                .day,
                "one agent's range must not change another's"
            )
        }
    }

    /// A value this build no longer recognizes falls back to the narrower
    /// window rather than to whatever sorts first.
    func testUnknownStoredRangeFallsBackToDay() {
        withDefaults { defaults in
            defaults.set("month", forKey: "tokenMonitor.range.codex")

            XCTAssertEqual(AppSettings(defaults: defaults).tokenMonitorRange(for: .codex), .day)
        }
    }

    private func withDefaults(_ operation: (UserDefaults) -> Void) {
        let suiteName = "TokenMonitorRangePersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        operation(defaults)
    }
}
