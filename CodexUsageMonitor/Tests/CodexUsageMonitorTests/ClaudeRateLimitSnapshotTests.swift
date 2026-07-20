import XCTest
@testable import CodexUsageMonitor

final class ClaudeRateLimitSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let snapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: ClaudeRateLimitWindow(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeRateLimitSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testEncodesEpochSecondsNotISO8601() throws {
        let snapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: nil,
            sevenDay: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["capturedAt"] as? Double, 1_700_000_000)
    }

    func testDecodesBridgeWrittenPartialWindowJSON() throws {
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """

        let decoded = try JSONDecoder().decode(ClaudeRateLimitSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.fiveHour, ClaudeRateLimitWindow(usedPercentage: 5.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertNil(decoded.sevenDay)
    }
}
