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

    func testSameSizeInPlaceRewriteRebuildsCachedTranscript() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let session = root.appendingPathComponent("rewritten-session.jsonl")
        let initial = codexTranscript(inputTokens: 100)
        let rewritten = codexTranscript(inputTokens: 200)
        XCTAssertEqual(initial.utf8.count, rewritten.utf8.count)
        try initial.write(to: session, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
            ofItemAtPath: session.path
        )

        let source = CodexLocalActivitySource(sessionsRoot: root)
        let first = await source.scan(bounds: LocalActivityScanBounds())
        XCTAssertEqual(first.requests.first?.tokens.totalTokens, 150)

        let handle = try FileHandle(forWritingTo: session)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(rewritten.utf8))
        try handle.close()
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_001)],
            ofItemAtPath: session.path
        )

        let second = await source.scan(bounds: LocalActivityScanBounds())
        XCTAssertEqual(second.status, .readable)
        XCTAssertEqual(second.requests.count, 1)
        XCTAssertEqual(second.requests.first?.tokens.totalTokens, 250)
    }

    func testLargerInPlaceMiddleRewriteRebuildsCachedTranscriptPrefix() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let session = root.appendingPathComponent("rewritten-session.jsonl")
        let padding = String(repeating: "\n", count: 5_000)
        let initial = padding + codexTranscript(inputTokens: 100) + padding
        let rewritten = padding + codexTranscript(inputTokens: 200) + padding
            + codexUsageEvent(turnID: "appended-turn", inputTokens: 300)
        XCTAssertGreaterThan(initial.utf8.count, 8 * 1_024)
        XCTAssertGreaterThan(rewritten.utf8.count, initial.utf8.count)
        try initial.write(to: session, atomically: true, encoding: .utf8)

        let source = CodexLocalActivitySource(sessionsRoot: root)
        let first = await source.scan(bounds: LocalActivityScanBounds())
        XCTAssertEqual(first.requests.map(\.tokens.totalTokens), [150])

        let handle = try FileHandle(forWritingTo: session)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(rewritten.utf8))
        try handle.close()

        let second = await source.scan(bounds: LocalActivityScanBounds())
        XCTAssertEqual(second.status, .readable)
        // The second cumulative watermark contributes only its 100-token
        // increase over the rewritten first watermark.
        XCTAssertEqual(second.requests.map(\.tokens.totalTokens).sorted(), [100, 250])
    }

    func testClaudeSameMessageWithDistinctRequestIDsRemainsDistinct() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let records = [
            claudeAssistantRecord(messageID: "message-1", requestID: "request-1", input: 100),
            claudeAssistantRecord(messageID: "message-1", requestID: "request-2", input: 200),
        ]
        try (records.joined(separator: "\n") + "\n").write(
            to: root.appendingPathComponent("conversation.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let result = await ClaudeLocalActivitySource(projectRoots: [root])
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.count, 2)
        XCTAssertEqual(result.requests.map(\.tokens.totalTokens).sorted(), [150, 250])
        XCTAssertEqual(Set(result.requests.map(\.id)).count, 2)
    }

    func testClaudeNestedAgentProgressAssistantContributesUsage() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = """
        {"type":"progress","timestamp":"2026-07-28T04:00:00Z","data":{"type":"agent_progress","message":\(claudeAssistantRecord(messageID: "nested-message", requestID: "nested-request", input: 300))}}
        """
        try (nested + "\n").write(
            to: root.appendingPathComponent("conversation.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let result = await ClaudeLocalActivitySource(projectRoots: [root])
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.count, 1)
        XCTAssertEqual(result.requests.first?.tokens.totalTokens, 350)
    }

    func testClaudeReplayDropsOnlySidechainPairsAndPreservesParentPairs() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let parent = [
            claudeAssistantRecord(messageID: "shared-message", requestID: "parent-1", input: 100),
            claudeAssistantRecord(messageID: "shared-message", requestID: "parent-2", input: 200),
        ]
        try (parent.joined(separator: "\n") + "\n").write(
            to: root.appendingPathComponent("parent.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try (claudeAssistantRecord(
            messageID: "shared-message",
            requestID: "sidechain-replay",
            input: 300,
            isSidechain: true
        ) + "\n").write(
            to: root.appendingPathComponent("sidechain.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let result = await ClaudeLocalActivitySource(projectRoots: [root])
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.map(\.tokens.totalTokens).sorted(), [150, 250])
    }

    private func codexTranscript(inputTokens: Int) -> String {
        [
            #"{"timestamp":"2026-07-28T04:00:00Z","type":"session_meta","payload":{"id":"rewritten-session"}}"#,
            #"{"timestamp":"2026-07-28T04:00:01Z","type":"turn_context","payload":{"model":"gpt-5.6-codex"}}"#,
            #"{"timestamp":"2026-07-28T04:00:02Z","type":"event_msg","payload":{"type":"token_count","turn_id":"rewritten-turn","info":{"last_token_usage":{"input_tokens":\#(inputTokens),"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0},"total_token_usage":{"input_tokens":\#(inputTokens),"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0}}}}"#,
        ].joined(separator: "\n") + "\n"
    }

    private func codexUsageEvent(turnID: String, inputTokens: Int) -> String {
        """
        {"timestamp":"2026-07-28T04:00:03Z","type":"event_msg","payload":{"type":"token_count","turn_id":"\(turnID)","info":{"last_token_usage":{"input_tokens":\(inputTokens),"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0},"total_token_usage":{"input_tokens":\(inputTokens),"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0}}}}
        """ + "\n"
    }

    private func temporaryDirectory() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func claudeAssistantRecord(
        messageID: String,
        requestID: String,
        input: Int,
        isSidechain: Bool = false
    ) -> String {
        """
        {"type":"assistant","timestamp":"2026-07-28T04:00:00Z","requestId":"\(requestID)","isSidechain":\(isSidechain),"message":{"id":"\(messageID)","model":"claude-sonnet","usage":{"input_tokens":\(input),"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
        """
    }
}
