import Foundation
import XCTest
@testable import CodexUsageMonitor

/// The passive status-line tier has never produced a snapshot in production.
/// Two defects kept it dead:
///
/// 1. `ClaudeStatusLineInstaller` had no call site in app code, so the shipped
///    app could neither install nor repair the capture.
/// 2. `install()` classified *any* foreign command as a user's custom status
///    line — including this project's own superseded bridge pointing at a
///    directory that no longer exists, which is the state found on the
///    reporting machine.
final class ClaudeStatusLineRepairTests: XCTestCase {
    func testAbsentStatusLineIsReportedAsNotConfigured() throws {
        let harness = try Harness()
        try harness.writeSettings(["model": "opus"])

        XCTAssertEqual(harness.installer.inspect(), .notConfigured)
    }

    func testOurOwnCurrentCommandIsReportedAsInstalled() throws {
        let harness = try Harness()
        _ = harness.installer.install()

        XCTAssertEqual(harness.installer.inspect(), .installed)
    }

    /// The exact shape found in production: this project's earlier Python
    /// bridge, pointing at a directory that has since been deleted.
    func testSupersededProjectBridgeIsRepairable() throws {
        let harness = try Harness()
        let stale = "cd '/nonexistent/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet"
        try harness.writeStatusLine(command: stale)

        guard case .repairable(let existing, let reason) = harness.installer.inspect() else {
            return XCTFail("a superseded project bridge must be repairable, got \(harness.installer.inspect())")
        }
        XCTAssertEqual(existing, stale)
        XCTAssertEqual(reason, .supersededProjectBridge)
    }

    func testForeignCommandNamingAMissingPathIsRepairable() throws {
        let harness = try Harness()
        let broken = "'/nonexistent/tool/statusline' --json"
        try harness.writeStatusLine(command: broken)

        guard case .repairable(_, let reason) = harness.installer.inspect() else {
            return XCTFail("a command whose executable is gone must be repairable")
        }
        XCTAssertEqual(reason, .brokenPath)
    }

    /// The protection that must not regress: a working third-party status line
    /// is never touched and never offered for replacement.
    func testWorkingForeignCommandIsLeftAlone() throws {
        let harness = try Harness()
        let foreign = "'/bin/echo' hello"
        try harness.writeStatusLine(command: foreign)

        XCTAssertEqual(harness.installer.inspect(), .foreign(existing: foreign))
        XCTAssertEqual(harness.installer.install(), .existingCustomStatusLineFound)
        XCTAssertEqual(try harness.currentCommand(), foreign, "a foreign status line must survive untouched")
    }

    func testRepairReplacesOnlyTheStatusLineAndOnlyWhenAsked() throws {
        let harness = try Harness()
        try harness.writeSettings([
            "model": "opus",
            "env": ["FOO": "bar"],
            "statusLine": ["type": "command", "command": "cd '/nonexistent/x' && python3 -m claude_usage_bridge"],
        ])

        // Without explicit confirmation the stale command stays put.
        XCTAssertEqual(harness.installer.install(), .existingCustomStatusLineFound)
        XCTAssertTrue(try harness.currentCommand().contains("claude_usage_bridge"))

        XCTAssertEqual(harness.installer.install(replacingExisting: true), .installed)
        XCTAssertEqual(try harness.currentCommand(), harness.expectedCommand)

        // Every unrelated key survives byte-for-byte.
        let root = try harness.readSettings()
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual((root["env"] as? [String: Any])?["FOO"] as? String, "bar")
    }

    func testMalformedSettingsAreRefusedRatherThanOverwritten() throws {
        let harness = try Harness()
        try "{ not json".write(to: harness.settingsURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(harness.installer.inspect(), .settingsUnreadable)
        XCTAssertEqual(harness.installer.install(replacingExisting: true), .unableToUpdateSettings)
        XCTAssertEqual(try String(contentsOf: harness.settingsURL, encoding: .utf8), "{ not json")
    }

    // MARK: Capture health

    func testCaptureHealthReportsNeverCapturedWhenNoSnapshotExists() {
        let health = ClaudePassiveCaptureHealth(
            state: .installed,
            lastCapturedAt: nil,
            now: Date(timeIntervalSince1970: 1_000)
        )
        XCTAssertFalse(health.isHealthy)
        XCTAssertTrue(health.summary.localizedCaseInsensitiveContains("never"))
    }

    func testCaptureHealthReportsAgeWhenASnapshotExists() {
        let health = ClaudePassiveCaptureHealth(
            state: .installed,
            lastCapturedAt: Date(timeIntervalSince1970: 0),
            now: Date(timeIntervalSince1970: 60)
        )
        XCTAssertTrue(health.isHealthy)
    }

    func testCaptureHealthNamesTheRepairWhenTheCommandIsStale() {
        let health = ClaudePassiveCaptureHealth(
            state: .repairable(existing: "old", reason: .supersededProjectBridge),
            lastCapturedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        XCTAssertFalse(health.isHealthy)
        XCTAssertNotNil(health.repairActionTitle)
    }

    // MARK: Harness

    private struct Harness {
        let directory: URL
        let settingsURL: URL
        let bridgeExecutable: URL
        let installer: ClaudeStatusLineInstaller
        let expectedCommand: String

        init() throws {
            directory = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            settingsURL = directory.appendingPathComponent("settings.json")
            bridgeExecutable = directory.appendingPathComponent("claude-usage-bridge")
            FileManager.default.createFile(atPath: bridgeExecutable.path, contents: Data())
            installer = ClaudeStatusLineInstaller(
                settingsURL: settingsURL,
                bridgeExecutable: bridgeExecutable
            )
            expectedCommand = "'\(bridgeExecutable.path)' --quiet"
        }

        func writeSettings(_ root: [String: Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: root)
            try data.write(to: settingsURL)
        }

        func writeStatusLine(command: String) throws {
            try writeSettings(["statusLine": ["type": "command", "command": command]])
        }

        func readSettings() throws -> [String: Any] {
            let data = try Data(contentsOf: settingsURL)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }

        func currentCommand() throws -> String {
            let statusLine = try XCTUnwrap(readSettings()["statusLine"] as? [String: Any])
            return try XCTUnwrap(statusLine["command"] as? String)
        }
    }
}
