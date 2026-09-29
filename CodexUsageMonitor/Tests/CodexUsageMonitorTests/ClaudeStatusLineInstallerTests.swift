import XCTest
@testable import CodexUsageMonitor

final class ClaudeStatusLineInstallerTests: XCTestCase {
    private var tempDirectory: URL!
    private var settingsURL: URL!
    private var bridgeExecutable: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeStatusLineInstallerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        settingsURL = tempDirectory.appendingPathComponent("settings.json")
        bridgeExecutable = tempDirectory
            .appendingPathComponent("ClaudeBridge/claude-usage-bridge")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testInstallCreatesSettingsFileWhenMissing() throws {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: bridgeExecutable)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        let statusLine = try XCTUnwrap(json["statusLine"] as? [String: Any])
        XCTAssertEqual(statusLine["type"] as? String, "command")
        XCTAssertEqual(statusLine["command"] as? String, "'\(bridgeExecutable.path)' --quiet")
    }

    /// Regression test: an earlier version left the bridge path unquoted, so a
    /// directory literally named "agent usage" (a space in the path) split into
    /// two shell words and the command failed with "No such file or directory".
    /// This runs the produced command through a real shell against such a path
    /// and proves the quoted executable path is exec'd as a single word.
    func testInstalledCommandSurvivesAPathContainingASpace() throws {
        let spacedDirectory = tempDirectory.appendingPathComponent("agent usage/ClaudeBridge")
        try FileManager.default.createDirectory(at: spacedDirectory, withIntermediateDirectories: true)
        let spacedExecutable = spacedDirectory.appendingPathComponent("claude-usage-bridge")
        // A stand-in executable that ignores args and prints a known token.
        try Data("#!/bin/bash\necho bridge-ran\n".utf8).write(to: spacedExecutable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: spacedExecutable.path)

        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: spacedExecutable)
        XCTAssertEqual(installer.install(), .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        let statusLine = try XCTUnwrap(json["statusLine"] as? [String: Any])
        let command = try XCTUnwrap(statusLine["command"] as? String)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(output, "bridge-ran")
    }

    func testInstallPreservesExistingUnrelatedKeys() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["theme": "dark", "hooks": ["SessionStart": []]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: bridgeExecutable)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        XCTAssertEqual(json["theme"] as? String, "dark")
        XCTAssertNotNil(json["hooks"])
        XCTAssertNotNil(json["statusLine"])
    }

    func testInstallIsIdempotentWhenAlreadyInstalled() {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: bridgeExecutable)
        XCTAssertEqual(installer.install(), .installed)

        XCTAssertEqual(installer.install(), .alreadyInstalled)
    }

    func testInstallRefusesToReplaceExistingCustomStatusLine() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["statusLine": ["type": "command", "command": "my-custom-script.sh"]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: bridgeExecutable)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .existingCustomStatusLineFound)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }

    func testInstallReturnsUnableToUpdateSettingsForMalformedJSONAndLeavesFileUntouched() throws {
        try Data("not json".utf8).write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeExecutable: bridgeExecutable)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .unableToUpdateSettings)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }
}
