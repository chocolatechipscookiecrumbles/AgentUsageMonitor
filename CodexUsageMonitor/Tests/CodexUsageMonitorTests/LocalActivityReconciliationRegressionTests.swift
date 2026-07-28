import Foundation
import XCTest
@testable import CodexUsageMonitor

final class LocalActivityReconciliationRegressionTests: XCTestCase {
    func testExactCumulativeReplayDoesNotInflateObservedTokens() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let session = root.appendingPathComponent("fabricated-session.jsonl")
        let lines = [
            #"{"timestamp":"2026-07-28T04:00:00Z","type":"session_meta","payload":{"id":"fabricated-session"}}"#,
            #"{"timestamp":"2026-07-28T04:00:01Z","type":"turn_context","payload":{"model":"gpt-5.6-codex"}}"#,
            #"{"timestamp":"2026-07-28T04:00:02Z","type":"event_msg","payload":{"type":"token_count","turn_id":"fabricated-turn","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":10},"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":10}}}}"#,
            #"{"timestamp":"2026-07-28T04:00:03Z","type":"event_msg","payload":{"type":"token_count","turn_id":"fabricated-turn","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":10},"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":50,"reasoning_output_tokens":10}}}}"#,
        ]
        try (lines.joined(separator: "\n") + "\n").write(
            to: session,
            atomically: true,
            encoding: .utf8
        )

        let result = await CodexLocalActivitySource(sessionsRoot: root)
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.count, 1)
        XCTAssertEqual(result.requests.first?.tokens.totalTokens, 150)
    }
}
