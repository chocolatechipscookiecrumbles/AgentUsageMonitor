import XCTest
@testable import CodexUsageMonitor

/// Providers spell plans in their own machine style, and every surface that
/// shows one goes through a single formatter so the popover header, the Settings
/// pages, and the context rail cannot name the same account differently.
final class AgentPlanNameTests: XCTestCase {
    func testSimplePlanIsCapitalized() {
        XCTAssertEqual(AgentPlanName.display("pro"), "Pro")
        XCTAssertEqual(AgentPlanName.display("plus"), "Plus")
    }

    /// `.capitalized` alone renders this as `Max_20x`, which is not a name any
    /// user would recognize.
    func testCompoundPlanReadsAsWordsAndKeepsItsMultiplier() {
        XCTAssertEqual(AgentPlanName.display("max_20x"), "Max 20x")
        XCTAssertEqual(AgentPlanName.display("chatgpt-plus"), "Chatgpt Plus")
    }

    func testAbsentOrEmptyPlanHasNoName() {
        XCTAssertNil(AgentPlanName.display(nil))
        XCTAssertNil(AgentPlanName.display(""))
        XCTAssertNil(AgentPlanName.display("   "))
    }

    func testUnrecognizedPlanFallsBackInsteadOfInventingAName() {
        XCTAssertNil(AgentPlanName.display("enterprise_custom"))
    }
}

/// The popover header names the account, because the tab directly above it
/// already names the provider.
final class MenuProviderHeaderTitleTests: XCTestCase {
    /// No quota record yet: the plan must come from the connection alone.
    private static let noRecord = QuotaDisplayState(
        mode: .cachedPaused,
        displayedRecord: nil,
        lastAttemptAt: .distantPast,
        lastConfirmedAt: nil,
        pauseReason: .unavailable
    )

    func testConnectedPlanBecomesTheHeaderTitle() {
        let header = MenuProviderHeaderPresentation.codex(
            displayState: Self.noRecord,
            connectionState: .connected(AgentAccountSummary(planType: "pro")),
            isRefreshing: false
        )

        XCTAssertEqual(header.title, "Pro")
    }

    /// Not knowing the tier is a normal state before the first reading lands.
    /// A blank header would read as a rendering fault, so the provider name is
    /// the fallback rather than an empty string or a guess.
    func testUnknownPlanFallsBackToTheProviderName() {
        let codex = MenuProviderHeaderPresentation.codex(
            displayState: Self.noRecord,
            connectionState: .disconnected,
            isRefreshing: false
        )
        let claude = MenuProviderHeaderPresentation.claude(
            usageState: .unavailable(reason: "no credential"),
            connectionState: .notConnected,
            isRefreshing: false
        )

        XCTAssertEqual(codex.title, "Codex")
        XCTAssertEqual(claude.title, "Claude")
    }

    func testClaudeConnectedPlanBecomesTheHeaderTitle() {
        let header = MenuProviderHeaderPresentation.claude(
            usageState: .unavailable(reason: "no reading yet"),
            connectionState: .connected(ClaudeAccountSummary(planType: "max_20x")),
            isRefreshing: false
        )

        XCTAssertEqual(header.title, "Max 20x")
    }

    /// The plan is account identity, not a property of the reading in flight,
    /// so it must survive a refresh rather than flicking back to the provider
    /// name for the duration.
    func testPlanSurvivesRefreshingAndUnavailableStates() {
        let refreshing = MenuProviderHeaderPresentation.codex(
            displayState: Self.noRecord,
            connectionState: .connected(AgentAccountSummary(planType: "team")),
            isRefreshing: true
        )

        XCTAssertEqual(refreshing.title, "Team")
        XCTAssertEqual(refreshing.subtitle, "Refreshing…")
    }

    func testClaudeHeaderDistinguishesCapturedConfirmedAndCachedReadings() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func state(delivery: ClaudeUsageDelivery, age: TimeInterval) -> ClaudeUsageState {
            .available(ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: nil,
                    fiveHour: ClaudeLimitWindow(usedPercent: 20, resetsAt: nil),
                    sevenDay: nil,
                    scopedWindows: [],
                    extraUsage: nil,
                    source: delivery == .live ? .oauth : .statusLine,
                    capturedAt: now.addingTimeInterval(-age),
                    schemaVersion: 1
                ),
                delivery: delivery,
                warnings: []
            ))
        }

        XCTAssertEqual(MenuProviderHeaderPresentation.claude(
            usageState: state(delivery: .passiveSnapshot, age: 120),
            connectionState: .notConnected,
            isRefreshing: false,
            now: now
        ).status, .captured)
        XCTAssertEqual(MenuProviderHeaderPresentation.claude(
            usageState: state(delivery: .live, age: 0),
            connectionState: .notConnected,
            isRefreshing: false,
            now: now
        ).status, .confirmed)
        XCTAssertEqual(MenuProviderHeaderPresentation.claude(
            usageState: state(delivery: .passiveSnapshot, age: 121),
            connectionState: .notConnected,
            isRefreshing: false,
            now: now
        ).status, .cached)
    }
}
