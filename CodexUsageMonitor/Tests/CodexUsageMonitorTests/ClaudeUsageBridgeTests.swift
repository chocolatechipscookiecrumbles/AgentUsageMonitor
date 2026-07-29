import XCTest
@testable import CodexUsageMonitor
import ClaudeUsageBridgeCore

/// Ports the former Python bridge tests (models / writer / cli) to the native
/// bridge, plus a cross-compatibility test proving the app's own reader decodes
/// exactly what the bridge writes.
final class ClaudeUsageBridgeTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageBridgeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: extractSnapshot

    func testExtractsBothWindows() throws {
        let payload = decodePayload("""
        {"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":100},
        "seven_day":{"used_percentage":8.5,"resets_at":200}}}
        """)
        let snapshot = try XCTUnwrap(extractSnapshot(from: payload, capturedAt: 1_000))
        XCTAssertEqual(snapshot.capturedAt, 1_000)
        XCTAssertEqual(snapshot.fiveHour, RateLimitWindow(usedPercentage: 42, resetsAt: 100))
        XCTAssertEqual(snapshot.sevenDay, RateLimitWindow(usedPercentage: 8.5, resetsAt: 200))
    }

    func testReturnsNilWhenRateLimitsAbsentOrNotAnObject() {
        XCTAssertNil(extractSnapshot(from: decodePayload("{}"), capturedAt: 0))
        XCTAssertNil(extractSnapshot(from: decodePayload("{\"rate_limits\":5}"), capturedAt: 0))
        XCTAssertNil(extractSnapshot(from: decodePayload("[]"), capturedAt: 0))
        XCTAssertNil(extractSnapshot(from: decodePayload("not json"), capturedAt: 0))
    }

    func testReturnsNilWhenNeitherWindowIsValid() {
        let payload = decodePayload("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":1}}}") // missing resets_at
        XCTAssertNil(extractSnapshot(from: payload, capturedAt: 0))
    }

    func testKeepsOnlyTheValidWindow() throws {
        // resets_at must be an integer; a fractional value is rejected.
        let payload = decodePayload("""
        {"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":150},
        "seven_day":{"used_percentage":30,"resets_at":150.5}}}
        """)
        let snapshot = try XCTUnwrap(extractSnapshot(from: payload, capturedAt: 0))
        XCTAssertEqual(snapshot.fiveHour, RateLimitWindow(usedPercentage: 30, resetsAt: 150))
        XCTAssertNil(snapshot.sevenDay)
    }

    func testRejectsBooleanFields() {
        // JSON booleans bridge to NSNumber; they must not be read as 0/1.
        let payload = decodePayload("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":true,\"resets_at\":100}}}")
        XCTAssertNil(extractSnapshot(from: payload, capturedAt: 0))
    }

    // MARK: statusLine

    func testStatusLineUnavailableWhenNilOrEmpty() {
        XCTAssertEqual(statusLine(for: nil), "Claude usage: unavailable")
    }

    func testStatusLineBothWindowsRoundsToWholePercent() {
        let snapshot = RateLimitSnapshot(
            capturedAt: 0,
            fiveHour: RateLimitWindow(usedPercentage: 42.7, resetsAt: 1),
            sevenDay: RateLimitWindow(usedPercentage: 10, resetsAt: 2)
        )
        XCTAssertEqual(statusLine(for: snapshot), "Claude usage: 5h 43% · 7d 10%")
    }

    func testStatusLineSingleWindow() {
        let snapshot = RateLimitSnapshot(
            capturedAt: 0,
            fiveHour: RateLimitWindow(usedPercentage: 5, resetsAt: 1),
            sevenDay: nil
        )
        XCTAssertEqual(statusLine(for: snapshot), "Claude usage: 5h 5%")
    }

    // MARK: writeSnapshot

    func testWritesAtomicallyWithOwnerOnlyPermissions() throws {
        let output = tempDirectory.appendingPathComponent("nested/claude-rate-limits.json")
        let snapshot = RateLimitSnapshot(
            capturedAt: 1_234,
            fiveHour: RateLimitWindow(usedPercentage: 20, resetsAt: 111),
            sevenDay: nil
        )
        try writeSnapshot(snapshot, to: output)

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: output)) as? [String: Any]
        XCTAssertEqual(object?["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object?["capturedAt"] as? Int, 1_234)
        XCTAssertNil(object?["sevenDay"], "absent window must be omitted, not null")

        let filePerms = try FileManager.default.attributesOfItem(atPath: output.path)[.posixPermissions] as? Int
        XCTAssertEqual(filePerms, 0o600)
        let dirPerms = try FileManager.default.attributesOfItem(
            atPath: output.deletingLastPathComponent().path
        )[.posixPermissions] as? Int
        XCTAssertEqual(dirPerms, 0o700)
    }

    func testWriteOverwritesAnExistingSnapshot() throws {
        let output = tempDirectory.appendingPathComponent("snap.json")
        try writeSnapshot(RateLimitSnapshot(capturedAt: 1, fiveHour: nil, sevenDay: RateLimitWindow(usedPercentage: 1, resetsAt: 1)), to: output)
        try writeSnapshot(RateLimitSnapshot(capturedAt: 2, fiveHour: nil, sevenDay: RateLimitWindow(usedPercentage: 2, resetsAt: 2)), to: output)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: output)) as? [String: Any]
        XCTAssertEqual(object?["capturedAt"] as? Int, 2)
    }

    // MARK: Cross-compatibility with the app reader

    func testAppReaderDecodesWhatTheBridgeWrites() throws {
        let output = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let snapshot = RateLimitSnapshot(
            capturedAt: 1_700_000_000,
            fiveHour: RateLimitWindow(usedPercentage: 63.5, resetsAt: 1_700_003_600),
            sevenDay: RateLimitWindow(usedPercentage: 12, resetsAt: 1_700_600_000)
        )
        try writeSnapshot(snapshot, to: output)

        let read = try XCTUnwrap(ClaudeRateLimitSnapshotReader(fileURL: output).readSnapshot())
        XCTAssertEqual(read.schemaVersion, 1)
        XCTAssertEqual(read.capturedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(read.fiveHour?.usedPercentage, 63.5)
        XCTAssertEqual(read.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_700_003_600))
        XCTAssertEqual(read.sevenDay?.usedPercentage, 12)
        XCTAssertEqual(read.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_700_600_000))
    }
}
