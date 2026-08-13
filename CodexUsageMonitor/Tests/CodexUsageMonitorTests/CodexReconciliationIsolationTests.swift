import Foundation
import XCTest
@testable import CodexUsageMonitor

/// Reproduces the two defects that made a live 295-file root report
/// `.unsafeToRead` with zero requests even though every file parsed:
///
/// 1. A reconciled **delta** was validated with an invariant that only holds for
///    a **cumulative snapshot** (`cached <= input`). Between two snapshots the
///    cached portion can grow faster than the total, which is exactly what
///    happens the first time a long prompt is served from cache.
/// 2. A single unreconcilable session threw out of the whole-root scan, so one
///    bad group blanked every other group's activity.
final class CodexReconciliationIsolationTests: XCTestCase {
    // MARK: Defect 1 — delta validated with a cumulative-snapshot invariant

    func testCachedGrowthExceedingInputGrowthIsStillReconciled() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Both snapshots satisfy cached <= input, so neither record is corrupt.
        // Their difference is input +50 but cached +1000 — the shape produced
        // when the second turn reuses a large cached prefix.
        let lines = [
            Self.sessionMeta(id: "cached-growth"),
            Self.turnContext(),
            Self.usage(at: "2026-08-12T04:00:02Z", input: 1_000, cached: 0, output: 100),
            Self.usage(at: "2026-08-12T04:00:03Z", input: 1_050, cached: 1_000, output: 150),
        ]
        try Self.write(lines, to: root.appendingPathComponent("cached-growth.jsonl"))

        let result = await CodexLocalActivitySource(sessionsRoot: root)
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.count, 2)
        // First delta: 1000 input + 100 output. Second: 50 input + 50 output.
        XCTAssertEqual(result.requests.map(\.tokens.totalTokens).sorted(), [100, 1_100])
        // The cached growth is retained rather than discarded or clamped.
        XCTAssertEqual(result.requests.compactMap(\.tokens.cachedInputTokens).max(), 1_000)
    }

    func testCodexBreakdownAcceptsDeltaWhereCachedExceedsInput() throws {
        // The type-level statement of defect 1: for Codex every breakdown holds
        // a reconciled delta, so the subset relationship must not be enforced.
        let breakdown = LocalActivityTokenBreakdown(
            provider: .codex,
            inputTokens: 50,
            cachedInputTokens: 1_000,
            outputTokens: 50,
            reasoningOutputTokens: 0
        )
        XCTAssertNotNil(breakdown)
        XCTAssertEqual(breakdown?.totalTokens, 100)
    }

    func testCodexBreakdownStillRejectsNegativeComponents() throws {
        // Relaxing the subset rule must not relax non-negativity, which is what
        // actually distinguishes corrupt input from a legitimate delta.
        XCTAssertNil(LocalActivityTokenBreakdown(
            provider: .codex, inputTokens: -1, cachedInputTokens: 0, outputTokens: 0
        ))
        XCTAssertNil(LocalActivityTokenBreakdown(
            provider: .codex, inputTokens: 10, cachedInputTokens: -5, outputTokens: 0
        ))
    }

    // MARK: Defect 2 — one unreconcilable session must not blank the root

    func testOneUnreconcilableSessionDoesNotBlankTheRoot() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // A fork whose parent is absent cannot have its inherited baseline
        // resolved, so this group legitimately fails to reconcile.
        try Self.write([
            Self.sessionMeta(id: "orphan-fork", parentSessionID: "absent-parent"),
            Self.turnContext(),
            Self.usage(at: "2026-08-12T05:00:02Z", input: 500, cached: 0, output: 50),
        ], to: root.appendingPathComponent("orphan-fork.jsonl"))

        try Self.write([
            Self.sessionMeta(id: "healthy"),
            Self.turnContext(),
            Self.usage(at: "2026-08-12T06:00:02Z", input: 200, cached: 0, output: 20),
        ], to: root.appendingPathComponent("healthy.jsonl"))

        let result = await CodexLocalActivitySource(sessionsRoot: root)
            .scan(bounds: LocalActivityScanBounds())

        XCTAssertEqual(result.status, .readable)
        XCTAssertEqual(result.requests.count, 1)
        XCTAssertEqual(result.requests.first?.tokens.totalTokens, 220)
    }

    func testRootWhereEverySessionFailsStaysUnsafeToRead() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        for name in ["orphan-a", "orphan-b"] {
            try Self.write([
                Self.sessionMeta(id: name, parentSessionID: "absent-parent"),
                Self.turnContext(),
                Self.usage(at: "2026-08-12T07:00:02Z", input: 100, cached: 0, output: 10),
            ], to: root.appendingPathComponent("\(name).jsonl"))
        }

        let result = await CodexLocalActivitySource(sessionsRoot: root)
            .scan(bounds: LocalActivityScanBounds())

        // Degrading per group must not let a wholly unreadable root look empty.
        XCTAssertEqual(result.status, .unsafeToRead)
        XCTAssertTrue(result.requests.isEmpty)
    }

    // MARK: Fixtures

    private func temporaryRoot() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func write(_ lines: [String], to url: URL) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func sessionMeta(id: String, parentSessionID: String? = nil) -> String {
        let parent = parentSessionID.map { #","parent_session_id":"\#($0)""# } ?? ""
        return #"{"timestamp":"2026-08-12T04:00:00Z","type":"session_meta","payload":{"id":"\#(id)"\#(parent)}}"#
    }

    private static func turnContext() -> String {
        #"{"timestamp":"2026-08-12T04:00:01Z","type":"turn_context","payload":{"model":"gpt-5.6-codex"}}"#
    }

    private static func usage(at timestamp: String, input: Int, cached: Int, output: Int) -> String {
        let usage = #"{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(output),"reasoning_output_tokens":0}"#
        return #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","turn_id":"turn","info":{"last_token_usage":\#(usage),"total_token_usage":\#(usage)}}}"#
    }
}
