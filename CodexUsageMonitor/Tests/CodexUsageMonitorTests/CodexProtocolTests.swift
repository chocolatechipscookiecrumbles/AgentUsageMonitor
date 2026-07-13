import XCTest
@testable import CodexUsageMonitor

final class CodexProtocolTests: XCTestCase {
    func test_parses_a_weekly_only_primary_window() throws {
        let sample = try weeklyOnlySample()

        XCTAssertNil(sample.fiveHour)
        XCTAssertEqual(sample.weekly.usedPercent, 1)
        XCTAssertEqual(sample.weekly.durationMinutes, 10_080)
    }

    func test_confirms_matching_weekly_only_samples() throws {
        let sample = try weeklyOnlySample()

        XCTAssertTrue(QuotaValidator.allMatch([sample, sample]))
    }

    private func weeklyOnlySample() throws -> CodexQuotaSample {
        try CodexProtocol.parseSample(
            responses: [
                2: ["result": ["account": ["email": "test@example.com"]]],
                3: [
                    "result": [
                        "rateLimits": [
                            "limitId": "codex",
                            "primary": [
                                "usedPercent": 1,
                                "windowDurationMins": 10_080,
                                "resetsAt": 1_784_513_329,
                            ],
                            "secondary": NSNull(),
                        ],
                    ],
                ],
            ],
            collectedAt: Date(timeIntervalSince1970: 1_784_000_000)
        )
    }
}
