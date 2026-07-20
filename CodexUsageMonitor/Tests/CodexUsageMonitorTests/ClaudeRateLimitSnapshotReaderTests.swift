import XCTest
@testable import CodexUsageMonitor

final class ClaudeRateLimitSnapshotReaderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeRateLimitSnapshotReaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testReadSnapshotReturnsNilWhenFileMissing() {
        let reader = ClaudeRateLimitSnapshotReader(fileURL: tempDirectory.appendingPathComponent("missing.json"))

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotReturnsNilForMalformedJSON() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        try Data("not json".utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotReturnsNilForWrongSchemaVersion() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 2, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 10.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotDecodesBothWindows() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, \
        "fiveHour": {"usedPercentage": 23.5, "resetsAt": 1800000000}, \
        "sevenDay": {"usedPercentage": 41.2, "resetsAt": 1800500000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        let snapshot = try XCTUnwrap(reader.readSnapshot())

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(snapshot.fiveHour, ClaudeRateLimitWindow(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertEqual(snapshot.sevenDay, ClaudeRateLimitWindow(usedPercentage: 41.2, resetsAt: Date(timeIntervalSince1970: 1_800_500_000)))
    }

    func testReadSnapshotDecodesPartialWindow() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        let snapshot = try XCTUnwrap(reader.readSnapshot())

        XCTAssertNotNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.sevenDay)
    }
}
