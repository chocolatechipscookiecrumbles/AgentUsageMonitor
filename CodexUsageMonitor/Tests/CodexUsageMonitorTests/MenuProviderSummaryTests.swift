import XCTest
@testable import CodexUsageMonitor

final class MenuProviderSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testClaudeSummaryIgnoresExpiredWindowWhenAnActiveWindowExists() {
        let state = makeState(
            fiveHour: ClaudeLimitWindow(
                usedPercent: 92,
                resetsAt: now.addingTimeInterval(-60)
            ),
            sevenDay: ClaudeLimitWindow(
                usedPercent: 37,
                resetsAt: now.addingTimeInterval(3_600)
            )
        )

        let summary = MenuProviderSummary.claude(usageState: state, now: now)

        XCTAssertEqual(summary.usedPercent, 37)
    }

    func testClaudeSummaryIsUnavailableWhenEveryWindowHasExpired() {
        let state = makeState(
            fiveHour: ClaudeLimitWindow(
                usedPercent: 92,
                resetsAt: now.addingTimeInterval(-60)
            ),
            sevenDay: ClaudeLimitWindow(
                usedPercent: 81,
                resetsAt: now.addingTimeInterval(-120)
            )
        )

        let summary = MenuProviderSummary.claude(usageState: state, now: now)

        XCTAssertNil(summary.usedPercent)
        XCTAssertNil(summary.freshness)
    }

    private func makeState(
        fiveHour: ClaudeLimitWindow?,
        sevenDay: ClaudeLimitWindow?
    ) -> ClaudeUsageState {
        .available(
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: "pro",
                    fiveHour: fiveHour,
                    sevenDay: sevenDay,
                    scopedWindows: [],
                    extraUsage: nil,
                    source: .oauth,
                    capturedAt: now,
                    schemaVersion: 1
                ),
                delivery: .live,
                warnings: []
            )
        )
    }
}
