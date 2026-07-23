import XCTest
@testable import CodexUsageMonitor

final class ClaudeSetupStateTests: XCTestCase {
    func testNeverConfiguredUnavailableAccountNeedsSetup() {
        let state = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .unavailable(reason: "No reading"),
            hasSetupHistory: false,
            hasCompletedSourceDiscovery: true
        )

        XCTAssertEqual(state, .notSetUp)
    }

    func testDurableSetupHistoryKeepsLapsedAccountOnExistingPage() {
        let state = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .unavailable(reason: "No reading"),
            hasSetupHistory: true,
            hasCompletedSourceDiscovery: true
        )

        XCTAssertEqual(state, .existingSetup)
    }

    func testAnyReadingCountsAsExistingSetup() {
        let presentation = ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: "pro",
                fiveHour: ClaudeLimitWindow(usedPercent: 12, resetsAt: nil),
                sevenDay: nil,
                scopedWindows: [],
                extraUsage: nil,
                source: .statusLine,
                capturedAt: .now,
                schemaVersion: 1
            ),
            delivery: .passiveSnapshot,
            warnings: []
        )

        let state = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .available(presentation),
            hasSetupHistory: false,
            hasCompletedSourceDiscovery: true
        )

        XCTAssertEqual(state, .existingSetup)
    }

    func testConnectionFailureKeepsRecoveryDetailsVisible() {
        let state = ClaudeSetupState.resolve(
            connectionState: .failed(.keychainAccessDenied),
            usageState: .unavailable(reason: "No reading"),
            hasSetupHistory: false,
            hasCompletedSourceDiscovery: true
        )

        XCTAssertEqual(state, .existingSetup)
    }

    func testSignInInProgressDoesNotReturnToOnboarding() {
        let state = ClaudeSetupState.resolve(
            connectionState: .signingIn(.claudeCodeCredentials),
            usageState: .unavailable(reason: "No reading"),
            hasSetupHistory: false,
            hasCompletedSourceDiscovery: true
        )

        XCTAssertEqual(state, .existingSetup)
    }

    func testConnectedAccountIsDurableSetupEvidence() {
        XCTAssertTrue(
            ClaudeSetupState.hasCurrentEvidence(
                connectionState: .connected(ClaudeAccountSummary(planType: "pro")),
                usageState: .unavailable(reason: "Refresh pending")
            )
        )
    }

    func testReadingIsDurableSetupEvidence() {
        let presentation = ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: nil,
                fiveHour: nil,
                sevenDay: ClaudeLimitWindow(usedPercent: 4, resetsAt: nil),
                scopedWindows: [],
                extraUsage: nil,
                source: .oauth,
                capturedAt: .now,
                schemaVersion: 1
            ),
            delivery: .live,
            warnings: []
        )

        XCTAssertTrue(
            ClaudeSetupState.hasCurrentEvidence(
                connectionState: .notConnected,
                usageState: .available(presentation)
            )
        )
    }

    func testUnavailableDisconnectedAccountIsNotDurableSetupEvidence() {
        XCTAssertFalse(
            ClaudeSetupState.hasCurrentEvidence(
                connectionState: .notConnected,
                usageState: .unavailable(reason: "No reading")
            )
        )
    }

    func testUnavailableAccountRemainsCheckingUntilInitialDiscoveryCompletes() {
        let state = ClaudeSetupState.resolve(
            connectionState: .notConnected,
            usageState: .unavailable(reason: "No reading"),
            hasSetupHistory: false,
            hasCompletedSourceDiscovery: false
        )

        XCTAssertEqual(state, .checking)
    }
}

@MainActor
final class ClaudeSetupHistoryPersistenceTests: XCTestCase {
    func testSetupHistoryDefaultsToFalse() {
        withDefaults { defaults in
            XCTAssertFalse(AppSettings(defaults: defaults).hasClaudeSetupHistory)
        }
    }

    func testRecordingSetupHistoryPersistsAcrossSettingsInstances() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            settings.recordClaudeSetupHistory()

            XCTAssertTrue(AppSettings(defaults: defaults).hasClaudeSetupHistory)
        }
    }

    func testLegacyCacheMigratesSetupHistory() throws {
        let applicationSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeSetupHistoryMigration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let appDirectory = applicationSupport.appendingPathComponent("CodexUsageMonitor")
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        try Data().write(to: appDirectory.appendingPathComponent("claude-usage-cache.json"))

        XCTAssertTrue(
            AppSettings.hasLegacyClaudeSetupEvidence(
                applicationSupportDirectory: applicationSupport
            )
        )
        withDefaults { defaults in
            let settings = AppSettings(
                defaults: defaults,
                legacyClaudeSetupEvidence: true
            )
            XCTAssertTrue(settings.hasClaudeSetupHistory)
            XCTAssertTrue(AppSettings(defaults: defaults).hasClaudeSetupHistory)
        }
    }

    func testMissingLegacyFilesDoNotMigrateSetupHistory() {
        let applicationSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeSetupHistoryMigration-\(UUID().uuidString)")

        XCTAssertFalse(
            AppSettings.hasLegacyClaudeSetupEvidence(
                applicationSupportDirectory: applicationSupport
            )
        )
    }

    private func withDefaults(_ operation: (UserDefaults) -> Void) {
        let suiteName = "ClaudeSetupHistoryPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        operation(defaults)
    }
}
