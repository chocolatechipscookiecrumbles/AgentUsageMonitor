import XCTest
@testable import CodexUsageMonitor

final class MenuBarProviderSelectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: Eligibility ("connected" providers)

    func testOnlyCodexEligibleWhenClaudeHasNoReading() {
        let eligible = MenuBarProviderSelection.eligibleProviders(
            codexDisplayState: codexState(fiveHourUsed: 20, weeklyUsed: 40),
            claudeState: .unavailable(reason: "none"),
            now: now
        )
        XCTAssertEqual(eligible, [.codex])
    }

    func testOnlyClaudeEligibleWhenCodexHasNoReading() {
        let eligible = MenuBarProviderSelection.eligibleProviders(
            codexDisplayState: emptyCodexState(),
            claudeState: claudeState(fiveHourUsed: 33, weeklyUsed: 55),
            now: now
        )
        XCTAssertEqual(eligible, [.claudeCode])
    }

    func testBothEligibleInCanonicalOrder() {
        let eligible = MenuBarProviderSelection.eligibleProviders(
            codexDisplayState: codexState(fiveHourUsed: 20, weeklyUsed: 40),
            claudeState: claudeState(fiveHourUsed: 33, weeklyUsed: 55),
            now: now
        )
        XCTAssertEqual(eligible, [.codex, .claudeCode])
    }

    func testNoneEligibleWhenNeitherHasData() {
        let eligible = MenuBarProviderSelection.eligibleProviders(
            codexDisplayState: emptyCodexState(),
            claudeState: .unavailable(reason: "none"),
            now: now
        )
        XCTAssertTrue(eligible.isEmpty)
    }

    // MARK: Effective provider

    func testStoredChoiceWinsWhenEligible() {
        XCTAssertEqual(
            MenuBarProviderSelection.effectiveProvider(stored: .claudeCode, eligible: [.codex, .claudeCode]),
            .claudeCode
        )
    }

    func testFallsBackToSoleConnectedProviderWhenStoredIsNotEligible() {
        XCTAssertEqual(
            MenuBarProviderSelection.effectiveProvider(stored: .claudeCode, eligible: [.codex]),
            .codex
        )
    }

    func testKeepsStoredChoiceWhenNothingIsEligible() {
        XCTAssertEqual(
            MenuBarProviderSelection.effectiveProvider(stored: .claudeCode, eligible: []),
            .claudeCode
        )
    }

    // MARK: Selector visibility

    func testSelectorHiddenWithFewerThanTwoProviders() {
        XCTAssertFalse(MenuBarProviderSelection.showsSelector(eligible: []))
        XCTAssertFalse(MenuBarProviderSelection.showsSelector(eligible: [.codex]))
    }

    func testSelectorShownWithTwoProviders() {
        XCTAssertTrue(MenuBarProviderSelection.showsSelector(eligible: [.codex, .claudeCode]))
    }

    // MARK: Fixtures

    private func codexState(fiveHourUsed: Int?, weeklyUsed: Int?) -> QuotaDisplayState {
        let presentation = QuotaPresentation(
            accountFingerprint: nil,
            limitID: nil,
            planType: "pro",
            creditBalance: nil,
            hasCredits: nil,
            availableResetCredits: nil,
            resetCreditExpiryDates: [],
            fiveHour: fiveHourUsed.map { QuotaWindow(usedPercent: $0, resetAt: now.addingTimeInterval(3_600), durationMinutes: 300) },
            weekly: weeklyUsed.map { QuotaWindow(usedPercent: $0, resetAt: now.addingTimeInterval(86_400), durationMinutes: 10_080) },
            confirmation: .confirmed,
            collectedAt: now,
            source: "test",
            detail: nil
        )
        return QuotaDisplayState(
            mode: .confirmedCompleted,
            displayedRecord: .withoutForecasts(presentation),
            lastAttemptAt: now,
            lastConfirmedAt: now,
            pauseReason: nil
        )
    }

    private func emptyCodexState() -> QuotaDisplayState {
        QuotaDisplayState(
            mode: .cachedPaused,
            displayedRecord: nil,
            lastAttemptAt: now,
            lastConfirmedAt: nil,
            pauseReason: .unavailable
        )
    }

    private func claudeState(fiveHourUsed: Int?, weeklyUsed: Int?) -> ClaudeUsageState {
        .available(
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: "pro",
                    fiveHour: fiveHourUsed.map { ClaudeLimitWindow(usedPercent: Double($0), resetsAt: now.addingTimeInterval(3_600)) },
                    sevenDay: weeklyUsed.map { ClaudeLimitWindow(usedPercent: Double($0), resetsAt: now.addingTimeInterval(86_400)) },
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
