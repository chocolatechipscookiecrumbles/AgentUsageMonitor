import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTripWithFullData() throws {
        let snapshot = ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: ClaudeLimitWindow(usedPercent: 8.0, resetsAt: Date(timeIntervalSince1970: 1_800_500_000)),
            scopedWindows: [
                ClaudeScopedLimitWindow(identifier: "session", displayName: "session", usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000))
            ],
            extraUsage: ClaudeExtraUsage(isEnabled: false, monthlyLimit: nil, usedCredits: nil, currencyCode: nil),
            source: .oauth,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeUsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testEncodeDecodeRoundTripWithMinimalData() throws {
        let snapshot = ClaudeUsageSnapshot(
            planHint: nil,
            fiveHour: nil,
            sevenDay: nil,
            scopedWindows: [],
            extraUsage: nil,
            source: .statusLine,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeUsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testPresentationCarriesDeliveryAndSourceIndependently() {
        let snapshot = ClaudeUsageSnapshot(
            planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: .oauth, capturedAt: .now, schemaVersion: 1
        )

        let presentation = ClaudeUsagePresentation(snapshot: snapshot, delivery: .cached, warnings: [])

        // A cached OAuth result must still report .oauth as its origin —
        // delivery (.cached) and source (.oauth) are tracked separately so
        // the cache never loses where the data originally came from.
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.delivery, .cached)
    }
}
