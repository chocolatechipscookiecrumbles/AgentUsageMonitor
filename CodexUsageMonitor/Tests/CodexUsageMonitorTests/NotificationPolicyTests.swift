import XCTest
@testable import CodexUsageMonitor

@MainActor
final class NotificationPolicyTests: XCTestCase {
    func test_reoffersStableInterruptionEventForBackedOffEpisodeWithoutTransition() {
        let episode = RefreshInterruptionEpisode(
            id: "episode-123",
            firstFailureAt: Date(timeIntervalSince1970: 1_784_000_000),
            lastConfirmedAt: Date(timeIntervalSince1970: 1_783_999_000),
            failureCount: 4
        )
        let record = QuotaRecord.withoutForecasts(QuotaPresentation(
            accountFingerprint: nil,
            limitID: nil,
            planType: nil,
            creditBalance: nil,
            hasCredits: nil,
            availableResetCredits: nil,
            resetCreditExpiryDates: [],
            fiveHour: nil,
            weekly: nil,
            confirmation: .unconfirmed,
            collectedAt: Date(timeIntervalSince1970: 1_784_000_000),
            source: "test",
            detail: nil
        ))

        let events = NotificationPolicy().evaluate(
            record,
            interruptionState: .backedOff(episode),
            interruptionTransition: .none,
            now: Date(timeIntervalSince1970: 1_784_000_000)
        )

        XCTAssertEqual(events.map(\.key), ["refresh-interruption-episode-123"])
    }
}
