import XCTest
@testable import CodexUsageMonitor

final class QuotaThresholdEvaluatorTests: XCTestCase {
    private let resetAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func window(usedPercent: Int, hasReset: Bool = false) -> QuotaWindow {
        QuotaWindow(usedPercent: usedPercent, resetAt: hasReset ? nil : resetAt, durationMinutes: nil)
    }

    /// A window that has dropped below several thresholds fires one alert per
    /// enabled threshold it has crossed, and none it has not.
    func testFiresOncePerCrossedEnabledThreshold() {
        // 8% remaining crosses 50/25/10 but not 5.
        let alerts = QuotaThresholdEvaluator.alerts(
            provider: .claudeCode,
            window: window(usedPercent: 92),
            name: "5-hour",
            isEnabled: { _ in true }
        )
        XCTAssertEqual(alerts.count, 3)
        XCTAssertTrue(alerts.allSatisfy { $0.body == "8% remains before the current limit resets." })
    }

    /// A real zero must alert; a missing window must not.
    func testRealZeroAlertsButMissingWindowDoesNot() {
        let zero = QuotaThresholdEvaluator.alerts(
            provider: .codex, window: window(usedPercent: 100), name: "Weekly", isEnabled: { _ in true }
        )
        XCTAssertEqual(zero.count, RemainingQuotaThreshold.allCases.count, "0% remaining crosses every threshold")

        let missing = QuotaThresholdEvaluator.alerts(
            provider: .codex, window: nil, name: "Weekly", isEnabled: { _ in true }
        )
        XCTAssertTrue(missing.isEmpty)
    }

    /// A window with no reset time cannot be deduped, so it produces no alert.
    func testWindowWithoutResetProducesNoAlert() {
        let alerts = QuotaThresholdEvaluator.alerts(
            provider: .claudeCode, window: window(usedPercent: 99, hasReset: true), name: "5-hour", isEnabled: { _ in true }
        )
        XCTAssertTrue(alerts.isEmpty)
    }

    func testDisabledThresholdsAreExcluded() {
        let alerts = QuotaThresholdEvaluator.alerts(
            provider: .codex,
            window: window(usedPercent: 95),
            name: "5-hour",
            isEnabled: { $0 == .ten }
        )
        XCTAssertEqual(alerts.map(\.key), [QuotaThresholdEvaluator.key(provider: .codex, name: "5-hour", resetAt: resetAt, threshold: .ten)])
    }

    /// Codex keeps its original provider-less key so the added provider
    /// dimension does not re-alert already-notified Codex episodes; Claude is
    /// namespaced and therefore distinct for the same window.
    func testCodexKeepsLegacyKeyWhileClaudeIsNamespaced() {
        let codexKey = QuotaThresholdEvaluator.key(provider: .codex, name: "5-hour", resetAt: resetAt, threshold: .ten)
        let claudeKey = QuotaThresholdEvaluator.key(provider: .claudeCode, name: "5-hour", resetAt: resetAt, threshold: .ten)

        XCTAssertEqual(codexKey, "quota-5-hour-\(resetAt.timeIntervalSince1970)-10")
        XCTAssertTrue(claudeKey.contains("claudeCode"))
        XCTAssertNotEqual(codexKey, claudeKey)
    }

    /// Claude's reset time carries fractional seconds that jitter between reads;
    /// the dedup key must stay stable so the alert is not re-delivered on every
    /// refresh.
    func testClaudeKeyIsStableAcrossSubSecondResetJitter() {
        let base = Date(timeIntervalSince1970: 1_800_000_033.111)
        let jittered = Date(timeIntervalSince1970: 1_800_000_033.987)
        XCTAssertEqual(
            QuotaThresholdEvaluator.key(provider: .claudeCode, name: "5-hour", resetAt: base, threshold: .fifty),
            QuotaThresholdEvaluator.key(provider: .claudeCode, name: "5-hour", resetAt: jittered, threshold: .fifty)
        )
    }

    /// A genuinely different reset window (hours later) still produces a distinct
    /// key, so a real reset re-arms the alert.
    func testDifferentResetWindowProducesDistinctKey() {
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let nextWindow = first.addingTimeInterval(5 * 3_600)
        XCTAssertNotEqual(
            QuotaThresholdEvaluator.key(provider: .claudeCode, name: "5-hour", resetAt: first, threshold: .fifty),
            QuotaThresholdEvaluator.key(provider: .claudeCode, name: "5-hour", resetAt: nextWindow, threshold: .fifty)
        )
    }

    /// Titles name the provider so a user can tell Codex and Claude alerts apart.
    func testTitleNamesTheProvider() {
        let codex = QuotaThresholdEvaluator.alerts(provider: .codex, window: window(usedPercent: 95), name: "5-hour", isEnabled: { $0 == .ten })
        let claude = QuotaThresholdEvaluator.alerts(provider: .claudeCode, window: window(usedPercent: 95), name: "5-hour", isEnabled: { $0 == .ten })
        XCTAssertEqual(codex.first?.title, "Codex 5-hour limit is low")
        XCTAssertEqual(claude.first?.title, "Claude 5-hour limit is low")
    }
}
