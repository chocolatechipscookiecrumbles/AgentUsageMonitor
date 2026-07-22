import XCTest
@testable import CodexUsageMonitor

private func codexPresentation(fiveHour: Int?, weekly: Int?, plan: String? = "pro") -> QuotaPresentation {
    QuotaPresentation(
        accountFingerprint: nil,
        limitID: nil,
        planType: plan,
        creditBalance: nil,
        hasCredits: nil,
        availableResetCredits: nil,
        resetCreditExpiryDates: [],
        fiveHour: fiveHour.map { QuotaWindow(usedPercent: $0, resetAt: nil, durationMinutes: nil) },
        weekly: weekly.map { QuotaWindow(usedPercent: $0, resetAt: nil, durationMinutes: nil) },
        confirmation: .confirmed,
        collectedAt: .now,
        source: "test",
        detail: nil
    )
}

private func claudePresentation(
    fiveHour: Double?,
    sevenDay: Double?,
    plan: String? = "pro",
    capturedAt: Date = .now
) -> ClaudeUsagePresentation {
    ClaudeUsagePresentation(
        snapshot: ClaudeUsageSnapshot(
            planHint: plan,
            fiveHour: fiveHour.map { ClaudeLimitWindow(usedPercent: $0, resetsAt: nil) },
            sevenDay: sevenDay.map { ClaudeLimitWindow(usedPercent: $0, resetsAt: nil) },
            scopedWindows: [],
            extraUsage: nil,
            source: .oauth,
            capturedAt: capturedAt,
            schemaVersion: 1
        ),
        delivery: .live,
        warnings: []
    )
}

final class ProviderContextSummaryTests: XCTestCase {
    private let now = Date()

    // MARK: Codex

    func testCodexConnectedReportsPlanLimitsAndConfirmedTimestamp() {
        let summary = ProviderContextSummary.codex(
            connectionState: .connected(AgentAccountSummary(planType: "pro")),
            presentation: codexPresentation(fiveHour: 44, weekly: 28),
            lastConfirmedAt: now.addingTimeInterval(-120),
            valueMode: .used,
            now: now
        )

        XCTAssertEqual(summary.provider, .codex)
        XCTAssertTrue(summary.isConnected)
        XCTAssertEqual(summary.statusText, "Connected")
        XCTAssertEqual(summary.planText, "Pro")
        XCTAssertEqual(summary.fiveHourText, "44%")
        XCTAssertEqual(summary.weeklyText, "28%")
        XCTAssertEqual(summary.lastRefreshText, "2 minutes ago")
    }

    /// The decision that a failing provider must not read as freshly
    /// refreshed: only a *confirmed* timestamp counts.
    func testCodexWithoutAConfirmedRefreshShowsUnavailable() {
        let summary = ProviderContextSummary.codex(
            connectionState: .connected(AgentAccountSummary(planType: "pro")),
            presentation: codexPresentation(fiveHour: 44, weekly: 28),
            lastConfirmedAt: nil,
            valueMode: .used,
            now: now
        )

        XCTAssertEqual(summary.lastRefreshText, ProviderContextSummary.placeholder)
    }

    func testCodexDisconnectedNeverShowsZeroPercent() {
        let summary = ProviderContextSummary.codex(
            connectionState: .disconnected,
            presentation: codexPresentation(fiveHour: nil, weekly: nil, plan: nil),
            lastConfirmedAt: nil,
            valueMode: .used,
            now: now
        )

        XCTAssertFalse(summary.isConnected)
        XCTAssertEqual(summary.statusText, ProviderContextSummary.disconnectedStatus)
        XCTAssertEqual(summary.fiveHourText, ProviderContextSummary.placeholder)
        XCTAssertEqual(summary.weeklyText, ProviderContextSummary.placeholder)
        XCTAssertNotEqual(summary.fiveHourText, "0%")
        XCTAssertEqual(summary.planText, ProviderContextSummary.placeholder)
    }

    func testCodexHonoursRemainingValueMode() {
        let summary = ProviderContextSummary.codex(
            connectionState: .connected(AgentAccountSummary(planType: "pro")),
            presentation: codexPresentation(fiveHour: 44, weekly: 28),
            lastConfirmedAt: now,
            valueMode: .remaining,
            now: now
        )

        XCTAssertEqual(summary.fiveHourText, "56%")
        XCTAssertEqual(summary.weeklyText, "72%")
    }

    // MARK: Claude

    func testClaudeConnectedReportsPlanLimitsAndCaptureTime() {
        let summary = ProviderContextSummary.claude(
            connectionState: .connected(ClaudeAccountSummary(planType: "pro")),
            usageState: .available(
                claudePresentation(fiveHour: 14, sevenDay: 25, capturedAt: now.addingTimeInterval(-8 * 60))
            ),
            now: now
        )

        XCTAssertEqual(summary.provider, .claudeCode)
        XCTAssertTrue(summary.isConnected)
        XCTAssertEqual(summary.statusText, "Connected")
        XCTAssertEqual(summary.planText, "Pro")
        XCTAssertEqual(summary.fiveHourText, "14%")
        XCTAssertEqual(summary.weeklyText, "25%")
        XCTAssertEqual(summary.lastRefreshText, "8 minutes ago")
    }

    func testClaudeUnavailableNeverShowsZeroPercent() {
        let summary = ProviderContextSummary.claude(
            connectionState: .notConnected,
            usageState: .unavailable(reason: "nope"),
            now: now
        )

        XCTAssertFalse(summary.isConnected)
        XCTAssertEqual(summary.statusText, ProviderContextSummary.disconnectedStatus)
        XCTAssertEqual(summary.fiveHourText, ProviderContextSummary.placeholder)
        XCTAssertEqual(summary.weeklyText, ProviderContextSummary.placeholder)
        XCTAssertNotEqual(summary.fiveHourText, "0%")
        XCTAssertEqual(summary.lastRefreshText, ProviderContextSummary.placeholder)
    }

    func testClaudeMissingWindowIsPlaceholderNotZero() {
        let summary = ProviderContextSummary.claude(
            connectionState: .connected(ClaudeAccountSummary(planType: "pro")),
            usageState: .available(claudePresentation(fiveHour: nil, sevenDay: 25)),
            now: now
        )

        XCTAssertEqual(summary.fiveHourText, ProviderContextSummary.placeholder)
        XCTAssertEqual(summary.weeklyText, "25%")
    }

    /// Both providers must render "last refresh" identically.
    func testBothProvidersShareTheSameRelativeWording() {
        let stamp = now.addingTimeInterval(-3 * 3600)
        let codex = ProviderContextSummary.codex(
            connectionState: .connected(AgentAccountSummary(planType: "pro")),
            presentation: codexPresentation(fiveHour: 1, weekly: 1),
            lastConfirmedAt: stamp,
            valueMode: .used,
            now: now
        )
        let claude = ProviderContextSummary.claude(
            connectionState: .connected(ClaudeAccountSummary(planType: "pro")),
            usageState: .available(claudePresentation(fiveHour: 1, sevenDay: 1, capturedAt: stamp)),
            now: now
        )

        XCTAssertEqual(codex.lastRefreshText, "3 hours ago")
        XCTAssertEqual(codex.lastRefreshText, claude.lastRefreshText)
    }

    // MARK: active providers

    func testActiveProvidersNeverIncludeCopilot() {
        let providers = ProviderContextSummary.activeProviders(claudeIsUsable: true)
        XCTAssertFalse(providers.contains(.githubCopilot), "Copilot's capability gate has not passed")
    }

    func testCodexIsAlwaysActiveAndClaudeIsConditional() {
        XCTAssertEqual(ProviderContextSummary.activeProviders(claudeIsUsable: true), [.codex, .claudeCode])
        XCTAssertEqual(ProviderContextSummary.activeProviders(claudeIsUsable: false), [.codex])
    }
}

/// "Resets" alone did not answer the question the row is asked — how long do
/// I have. The left side now carries the remaining duration.
final class RelativeTimeTextDurationTests: XCTestCase {
    private let now = Date()

    func testMinutesOnlyUnderAnHour() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(18 * 60), from: now), "in 18m")
    }

    func testHoursAndMinutes() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(2 * 3600 + 18 * 60), from: now), "in 2h 18m")
    }

    func testDropsZeroMinutes() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(3 * 3600), from: now), "in 3h")
    }

    func testDaysAndHours() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(5 * 86400 + 13 * 3600), from: now), "in 5d 13h")
    }

    func testUnderAMinuteReadsAsImminent() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(30), from: now), "in under a minute")
    }

    /// A window past its reset must not render a negative or absurd duration.
    func testPastResetReadsAsElapsed() {
        XCTAssertEqual(RelativeTimeText.duration(until: now.addingTimeInterval(-60), from: now), "now")
    }
}

/// The used/remaining setting is one control for the whole app. Providers
/// must not disagree about which one they are showing.
final class ProviderValueModeConsistencyTests: XCTestCase {
    private let now = Date()

    private func summaries(_ mode: QuotaValueMode) -> (codex: ProviderContextSummary, claude: ProviderContextSummary) {
        (
            .codex(
                connectionState: .connected(AgentAccountSummary(planType: "pro")),
                presentation: codexPresentationForMode(fiveHour: 44, weekly: 28),
                lastConfirmedAt: now,
                valueMode: mode,
                now: now
            ),
            .claude(
                connectionState: .connected(ClaudeAccountSummary(planType: "pro")),
                usageState: .available(claudePresentationForMode(fiveHour: 44, sevenDay: 28)),
                valueMode: mode,
                now: now
            )
        )
    }

    func testBothProvidersShowUsedWhenTheSettingIsUsed() {
        let (codex, claude) = summaries(.used)
        XCTAssertEqual(codex.fiveHourText, "44%")
        XCTAssertEqual(claude.fiveHourText, "44%", "Claude must follow the same setting as Codex")
        XCTAssertEqual(codex.weeklyText, claude.weeklyText)
    }

    func testBothProvidersShowRemainingWhenTheSettingIsRemaining() {
        let (codex, claude) = summaries(.remaining)
        XCTAssertEqual(codex.fiveHourText, "56%")
        XCTAssertEqual(claude.fiveHourText, "56%", "Claude previously hardcoded used and disagreed with Codex")
        XCTAssertEqual(codex.weeklyText, claude.weeklyText)
    }

    func testTheTwoProvidersNeverDisagreeForEitherSetting() {
        for mode in QuotaValueMode.allCases {
            let (codex, claude) = summaries(mode)
            XCTAssertEqual(codex.fiveHourText, claude.fiveHourText, "\(mode) five-hour")
            XCTAssertEqual(codex.weeklyText, claude.weeklyText, "\(mode) weekly")
        }
    }
}

private func codexPresentationForMode(fiveHour: Int, weekly: Int) -> QuotaPresentation {
    QuotaPresentation(
        accountFingerprint: nil, limitID: nil, planType: "pro", creditBalance: nil,
        hasCredits: nil, availableResetCredits: nil, resetCreditExpiryDates: [],
        fiveHour: QuotaWindow(usedPercent: fiveHour, resetAt: nil, durationMinutes: nil),
        weekly: QuotaWindow(usedPercent: weekly, resetAt: nil, durationMinutes: nil),
        confirmation: .confirmed, collectedAt: .now, source: "test", detail: nil
    )
}

private func claudePresentationForMode(fiveHour: Double, sevenDay: Double) -> ClaudeUsagePresentation {
    ClaudeUsagePresentation(
        snapshot: ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: fiveHour, resetsAt: nil),
            sevenDay: ClaudeLimitWindow(usedPercent: sevenDay, resetsAt: nil),
            scopedWindows: [], extraUsage: nil,
            source: .oauth, capturedAt: .now, schemaVersion: 1
        ),
        delivery: .live, warnings: []
    )
}
