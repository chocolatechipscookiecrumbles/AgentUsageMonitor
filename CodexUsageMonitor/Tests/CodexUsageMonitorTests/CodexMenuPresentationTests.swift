import XCTest
@testable import CodexUsageMonitor

final class CodexMenuPresentationTests: XCTestCase {
    func testCreditsBoundExpiryRowsAndReportTheHiddenCount() throws {
        let expiries = (1...5).map {
            Date(timeIntervalSince1970: 2_000_000_000 + Double($0 * 3_600))
        }
        let quota = QuotaPresentation(
            accountFingerprint: "test-account",
            limitID: "codex",
            planType: "pro",
            creditBalance: "12.34567",
            hasCredits: true,
            availableResetCredits: 5,
            resetCreditExpiryDates: expiries,
            fiveHour: QuotaWindow(usedPercent: 20, resetAt: nil, durationMinutes: 300),
            weekly: QuotaWindow(usedPercent: 30, resetAt: nil, durationMinutes: 10_080),
            confirmation: .confirmed,
            collectedAt: Date(timeIntervalSince1970: 2_000_000_000),
            source: "test",
            detail: nil
        )
        let state = QuotaDisplayState(
            mode: .confirmedCompleted,
            displayedRecord: .withoutForecasts(quota),
            lastAttemptAt: quota.collectedAt,
            lastConfirmedAt: quota.collectedAt,
            pauseReason: nil
        )

        let presentation = try XCTUnwrap(
            CodexMenuPresentation(
                displayState: state,
                fiveHourForecast: nil,
                weeklyForecast: nil
            )
        )
        let credits = try XCTUnwrap(presentation.credits)

        XCTAssertEqual(credits.visibleResetCreditExpiryDates, Array(expiries.prefix(2)))
        XCTAssertEqual(credits.hiddenResetCreditExpiryCount, 3)
    }
}
