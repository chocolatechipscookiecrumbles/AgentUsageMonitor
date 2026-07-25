import XCTest
@testable import CodexUsageMonitor

final class ThresholdConfirmationMessageTests: XCTestCase {
    private func pending(_ provider: AgentProvider, _ threshold: RemainingQuotaThreshold) -> PendingThresholdConfirmation {
        PendingThresholdConfirmation(provider: provider, threshold: threshold)
    }

    func testSingleThresholdReadsNaturally() {
        let body = ThresholdConfirmationMessage.body(for: [pending(.claudeCode, .twentyFive)])
        XCTAssertEqual(body, "Will warn you when Claude reaches 25%.")
    }

    /// Several thresholds for one provider are summarized, highest first.
    func testMultipleThresholdsOneProviderAreSummarizedDescending() {
        let body = ThresholdConfirmationMessage.body(for: [
            pending(.codex, .ten),
            pending(.codex, .fifty),
            pending(.codex, .twentyFive),
        ])
        XCTAssertEqual(body, "Will warn you when Codex reaches 50%, 25%, and 10%.")
    }

    /// Toggles across providers coalesce into one message in provider order.
    func testMultipleProvidersCoalesceInOrder() {
        let body = ThresholdConfirmationMessage.body(for: [
            pending(.claudeCode, .ten),
            pending(.codex, .twentyFive),
        ])
        XCTAssertEqual(body, "Will warn you when Codex reaches 25% and Claude reaches 10%.")
    }

    func testEmptyProducesNoMessage() {
        XCTAssertNil(ThresholdConfirmationMessage.body(for: []))
    }

    /// A Set is deduplicated, so the same toggle counted twice reads once.
    func testDuplicatePendingIsCollapsed() {
        let body = ThresholdConfirmationMessage.body(for: [
            pending(.codex, .five),
            pending(.codex, .five),
        ])
        XCTAssertEqual(body, "Will warn you when Codex reaches 5%.")
    }
}
