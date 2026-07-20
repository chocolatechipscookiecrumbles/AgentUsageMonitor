import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageMonitorTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageMonitorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @MainActor
    func testStateIsNotAvailableBeforeAnySnapshotExists() {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))

        monitor.refreshNow()

        XCTAssertEqual(monitor.state, .notAvailable)
    }

    @MainActor
    func testStateBecomesAvailableAfterSnapshotWritten() throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)

        monitor.refreshNow()

        guard case .available(let snapshot) = monitor.state else {
            return XCTFail("Expected .available")
        }
        XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 5.0)
    }

    @MainActor
    func testStateReturnsToNotAvailableIfSnapshotDisappears() throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))
        try Data("""
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """.utf8).write(to: fileURL)
        monitor.refreshNow()
        XCTAssertNotEqual(monitor.state, .notAvailable)

        try FileManager.default.removeItem(at: fileURL)
        monitor.refreshNow()

        XCTAssertEqual(monitor.state, .notAvailable)
    }

    @MainActor
    func testStartReadsImmediatelyWithoutWaitingForFirstTick() {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL), pollInterval: .seconds(300))

        monitor.start()

        XCTAssertEqual(monitor.state, .notAvailable)
        monitor.stop()
    }

    @MainActor
    func testStopPreventsFurtherPolling() async throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL), pollInterval: .milliseconds(20))
        monitor.start()
        monitor.stop()
        try Data("""
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """.utf8).write(to: fileURL)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(monitor.state, .notAvailable)
    }
}
