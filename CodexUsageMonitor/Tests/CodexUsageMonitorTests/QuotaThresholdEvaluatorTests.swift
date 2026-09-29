import XCTest
@testable import CodexUsageMonitor

private actor BlockingNotificationDelivery {
    private var identifiers: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var failsNext = true

    func add(identifier: String) async throws {
        identifiers.append(identifier)
        if failsNext {
            failsNext = false
            throw Failure()
        }
        await withCheckedContinuation { continuation = $0 }
    }

    func count() -> Int { identifiers.count }

    func release() {
        continuation?.resume()
        continuation = nil
    }

    private struct Failure: Error {}
}

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

final class ClaudeThresholdEligibilityTests: XCTestCase {
    func testOnlyCurrentReadingsWithFutureResetsReachThresholdEvaluation() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func presentation(
            delivery: ClaudeUsageDelivery,
            source: ClaudeUsageSource,
            age: TimeInterval,
            resetOffset: TimeInterval = 60
        ) -> ClaudeUsagePresentation {
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: nil,
                    fiveHour: ClaudeLimitWindow(
                        usedPercent: 90,
                        resetsAt: now.addingTimeInterval(resetOffset)
                    ),
                    sevenDay: nil,
                    scopedWindows: [],
                    extraUsage: nil,
                    source: source,
                    capturedAt: now.addingTimeInterval(-age),
                    schemaVersion: 1
                ),
                delivery: delivery,
                warnings: []
            )
        }

        XCTAssertNotNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .passiveSnapshot, source: .statusLine, age: 0), now: now
        )?.fiveHour)
        XCTAssertNotNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .passiveSnapshot, source: .statusLine, age: 120), now: now
        )?.fiveHour)
        XCTAssertNotNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .live, source: .oauth, age: 500), now: now
        )?.fiveHour)
        XCTAssertNotNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .live, source: .cli, age: 500), now: now
        )?.fiveHour)

        XCTAssertNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .cached, source: .oauth, age: 0), now: now
        ))
        XCTAssertNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .passiveSnapshot, source: .statusLine, age: 121), now: now
        ))
        XCTAssertNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .passiveSnapshot, source: .statusLine, age: -1), now: now
        ))
        XCTAssertNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .live, source: .statusLine, age: 0), now: now
        ))
        XCTAssertNil(QuotaViewModel.claudeThresholdWindows(
            for: presentation(delivery: .live, source: .oauth, age: 0, resetOffset: 0), now: now
        )?.fiveHour)
    }

    func testSourceTransitionsAndReconstructionKeepTheSameDedupKey() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetAt = now.addingTimeInterval(3_600)
        func presentation(
            delivery: ClaudeUsageDelivery,
            source: ClaudeUsageSource
        ) -> ClaudeUsagePresentation {
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: nil,
                    fiveHour: ClaudeLimitWindow(usedPercent: 95, resetsAt: resetAt),
                    sevenDay: nil,
                    scopedWindows: [],
                    extraUsage: nil,
                    source: source,
                    capturedAt: now,
                    schemaVersion: 1
                ),
                delivery: delivery,
                warnings: []
            )
        }
        let readings: [(ClaudeUsageDelivery, ClaudeUsageSource)] = [
            (.passiveSnapshot, .statusLine),
            (.live, .oauth),
            (.live, .cli),
        ]
        let keys = try readings.map { delivery, source in
            let window = try XCTUnwrap(QuotaViewModel.claudeThresholdWindows(
                for: presentation(delivery: delivery, source: source), now: now
            )?.fiveHour)
            return try XCTUnwrap(QuotaThresholdEvaluator.alerts(
                provider: .claudeCode,
                window: window,
                name: "5-hour",
                isEnabled: { $0 == .ten }
            ).first?.key)
        }
        let reconstructedKey = try XCTUnwrap(QuotaThresholdEvaluator.alerts(
            provider: .claudeCode,
            window: QuotaWindow(usedPercent: 95, resetAt: resetAt, durationMinutes: nil),
            name: "5-hour",
            isEnabled: { $0 == .ten }
        ).first?.key)

        XCTAssertEqual(Set(keys + [reconstructedKey]), [
            QuotaThresholdEvaluator.key(
                provider: .claudeCode,
                name: "5-hour",
                resetAt: resetAt,
                threshold: .ten
            )
        ])
    }

    func testEachWindowIsFilteredIndependently() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = ClaudeLimitWindow(usedPercent: 90, resetsAt: now.addingTimeInterval(60))
        let expired = ClaudeLimitWindow(usedPercent: 90, resetsAt: now)
        func windows(
            fiveHour: ClaudeLimitWindow?,
            weekly: ClaudeLimitWindow?
        ) -> (fiveHour: QuotaWindow?, weekly: QuotaWindow?)? {
            QuotaViewModel.claudeThresholdWindows(
                for: ClaudeUsagePresentation(
                    snapshot: ClaudeUsageSnapshot(
                        planHint: nil,
                        fiveHour: fiveHour,
                        sevenDay: weekly,
                        scopedWindows: [],
                        extraUsage: nil,
                        source: .oauth,
                        capturedAt: now,
                        schemaVersion: 1
                    ),
                    delivery: .live,
                    warnings: []
                ),
                now: now
            )
        }

        for weekly in [expired, nil] {
            let result = windows(fiveHour: valid, weekly: weekly)
            XCTAssertNotNil(result?.fiveHour)
            XCTAssertNil(result?.weekly)
        }
        for fiveHour in [expired, nil] {
            let result = windows(fiveHour: fiveHour, weekly: valid)
            XCTAssertNil(result?.fiveHour)
            XCTAssertNotNil(result?.weekly)
        }
    }
}

@MainActor
final class QuotaNotifierDedupTests: XCTestCase {
    func testFailedDeliveryCanRetryWhileConcurrentDuplicateIsSuppressed() async {
        let suiteName = "QuotaNotifierDedupTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        settings.alertsEnabled = true
        for threshold in RemainingQuotaThreshold.allCases {
            settings.setQuotaThreshold(threshold, enabled: threshold == .ten, for: .claudeCode)
        }
        let delivery = BlockingNotificationDelivery()
        let notifier = QuotaNotifier(
            settings: settings,
            defaults: defaults,
            addRequest: { request in
                try await delivery.add(identifier: request.identifier)
            }
        )
        let resetAt = Date(timeIntervalSince1970: 1_800_000_000)
        let window = QuotaWindow(usedPercent: 95, resetAt: resetAt, durationMinutes: nil)
        let key = QuotaThresholdEvaluator.key(
            provider: .claudeCode,
            name: "5-hour",
            resetAt: resetAt,
            threshold: .ten
        )

        await notifier.evaluateClaudeThresholds(fiveHour: window, weekly: nil)
        XCTAssertFalse(defaults.bool(forKey: key), "failed delivery must remain retryable")

        let retry = Task { await notifier.evaluateClaudeThresholds(fiveHour: window, weekly: nil) }
        for _ in 0..<500 {
            if await delivery.count() == 2 { break }
            await Task.yield()
        }
        let duplicate = Task { await notifier.evaluateClaudeThresholds(fiveHour: window, weekly: nil) }
        await duplicate.value

        let deliveryCount = await delivery.count()
        XCTAssertEqual(deliveryCount, 2, "an in-flight key must be submitted only once")
        await delivery.release()
        await retry.value
        XCTAssertTrue(defaults.bool(forKey: key), "successful delivery must persist deduplication")
    }
}
