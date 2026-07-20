import XCTest
@testable import CodexUsageMonitor

final class ClaudeStatusLineInstallerTests: XCTestCase {
    private var tempDirectory: URL!
    private var settingsURL: URL!
    private var bridgeDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeStatusLineInstallerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        settingsURL = tempDirectory.appendingPathComponent("settings.json")
        bridgeDirectory = tempDirectory.appendingPathComponent("ClaudeUsageBridge")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testInstallCreatesSettingsFileWhenMissing() throws {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        let statusLine = try XCTUnwrap(json["statusLine"] as? [String: Any])
        XCTAssertEqual(statusLine["type"] as? String, "command")
        XCTAssertEqual(statusLine["command"] as? String, "cd \(bridgeDirectory.path) && python3 -m claude_usage_bridge --quiet")
    }

    func testInstallPreservesExistingUnrelatedKeys() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["theme": "dark", "hooks": ["SessionStart": []]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        XCTAssertEqual(json["theme"] as? String, "dark")
        XCTAssertNotNil(json["hooks"])
        XCTAssertNotNil(json["statusLine"])
    }

    func testInstallIsIdempotentWhenAlreadyInstalled() {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        XCTAssertEqual(installer.install(), .installed)

        XCTAssertEqual(installer.install(), .alreadyInstalled)
    }

    func testInstallRefusesToReplaceExistingCustomStatusLine() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["statusLine": ["type": "command", "command": "my-custom-script.sh"]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .existingCustomStatusLineFound)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }

    func testInstallReturnsUnableToUpdateSettingsForMalformedJSONAndLeavesFileUntouched() throws {
        try Data("not json".utf8).write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .unableToUpdateSettings)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }
}
