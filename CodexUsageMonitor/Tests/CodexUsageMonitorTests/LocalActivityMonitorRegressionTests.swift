import Foundation
import XCTest
@testable import CodexUsageMonitor

@MainActor
final class LocalActivityMonitorRegressionTests: XCTestCase {
    func testDisablingBeforeStartPurgesPersistedProviderCache() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = LocalActivityCache(fileURL: root.appendingPathComponent("activity.json"))
        defer { try? FileManager.default.removeItem(at: root) }

        let tokens = try XCTUnwrap(
            LocalActivityTokenBreakdown(
                provider: .codex,
                inputTokens: 100,
                cachedInputTokens: 0,
                outputTokens: 50,
                reasoningOutputTokens: 0
            )
        )
        cache.save([
            .codex: [
                LocalActivityRequest(
                    id: "cached-request",
                    provider: .codex,
                    occurredAt: .now,
                    modelID: "gpt-test",
                    tokens: tokens
                ),
            ],
        ])
        XCTAssertNotNil(cache.load()[.codex])

        let source = ResetRecordingLocalActivitySource()
        let monitor = LocalActivityMonitor(
            sources: [.codex: source],
            rootsByProvider: [.codex: []],
            cache: cache
        )
        monitor.setCollectionEnabled(false, for: .codex)

        XCTAssertNil(cache.load()[.codex])
    }

    func testDisablingBeforeStartPurgesPriorSchemaProviderCache() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let tokens = try XCTUnwrap(
            LocalActivityTokenBreakdown(
                provider: .codex,
                inputTokens: 100,
                cachedInputTokens: 0,
                outputTokens: 50,
                reasoningOutputTokens: 0
            )
        )
        let oldEntry = LocalActivityCachedRequests(
            schemaVersion: 1,
            provider: .codex,
            savedAt: .now,
            requests: [
                LocalActivityRequest(
                    id: "old-schema-request",
                    provider: .codex,
                    occurredAt: .now,
                    modelID: "gpt-test",
                    tokens: tokens
                ),
            ]
        )
        try JSONEncoder().encode([oldEntry]).write(to: cacheURL)

        let monitor = LocalActivityMonitor(
            sources: [.codex: ResetRecordingLocalActivitySource()],
            rootsByProvider: [.codex: []],
            cache: LocalActivityCache(fileURL: cacheURL)
        )
        monitor.setCollectionEnabled(false, for: .codex)

        let remaining = (try? Data(contentsOf: cacheURL))
            .flatMap { try? JSONDecoder().decode([LocalActivityCachedRequests].self, from: $0) }
        XCTAssertFalse(remaining?.contains { $0.provider == .codex } ?? false)
    }

    func testDisablingBeforeStartDeletesUnreadableCacheFile() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"[{"persisted":"provider requests"}]"#.utf8).write(to: cacheURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: cacheURL.path
        )

        let monitor = LocalActivityMonitor(
            sources: [.codex: ResetRecordingLocalActivitySource()],
            rootsByProvider: [.codex: []],
            cache: LocalActivityCache(fileURL: cacheURL)
        )
        monitor.setCollectionEnabled(false, for: .codex)

        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testDisablingBeforeStartResetsDecodedSourceState() async {
        let source = ResetRecordingLocalActivitySource()
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = root.appendingPathComponent("activity.json")
        defer { try? FileManager.default.removeItem(at: root) }
        let monitor = LocalActivityMonitor(
            sources: [.codex: source],
            rootsByProvider: [.codex: []],
            cache: LocalActivityCache(fileURL: cacheURL)
        )

        monitor.setCollectionEnabled(false, for: .codex)

        for _ in 0..<50 where await source.resetCount == 0 {
            await Task.yield()
        }
        let resetCount = await source.resetCount
        XCTAssertEqual(resetCount, 1)
    }

    func testDisableThenReenableCannotPublishInterruptedScan() async throws {
        let source = BlockingLocalActivitySource()
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let monitor = LocalActivityMonitor(
            sources: [.codex: source],
            rootsByProvider: [.codex: []],
            cache: LocalActivityCache(fileURL: root.appendingPathComponent("activity.json"))
        )
        monitor.start()
        defer { monitor.stop() }

        for _ in 0..<1_000 where await source.scanCount == 0 {
            await Task.yield()
        }
        let initialScanCount = await source.currentScanCount()
        XCTAssertEqual(initialScanCount, 1)

        monitor.setCollectionEnabled(false, for: .codex)
        monitor.setCollectionEnabled(true, for: .codex)
        await source.releaseInterruptedScan()

        for _ in 0..<5_000 {
            if case .available(let snapshot) = monitor.state(for: .codex),
               snapshot.lastRequest?.id == "fresh" {
                break
            }
            await Task.yield()
        }

        guard case .available(let snapshot) = monitor.state(for: .codex) else {
            return XCTFail("Expected the post-reset scan to publish")
        }
        XCTAssertEqual(snapshot.lastRequest?.id, "fresh")
        let resetCount = await source.currentResetCount()
        let scanCount = await source.currentScanCount()
        XCTAssertEqual(resetCount, 2)
        XCTAssertEqual(scanCount, 2)
    }
}

private actor ResetRecordingLocalActivitySource: LocalActivitySource {
    nonisolated let provider: AgentProvider = .codex
    private(set) var resetCount = 0

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        LocalActivityScanResult(requests: [], cursors: [], status: .localRecordsMissing)
    }

    func reset() {
        resetCount += 1
    }
}

private actor BlockingLocalActivitySource: LocalActivitySource {
    nonisolated let provider: AgentProvider = .codex
    private(set) var scanCount = 0
    private var resetCount = 0
    private var interruptedScanContinuation: CheckedContinuation<Void, Never>?

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        scanCount += 1
        if scanCount == 1 {
            await withCheckedContinuation { continuation in
                interruptedScanContinuation = continuation
            }
            return result(id: "stale", input: 100)
        }
        return result(id: "fresh", input: 200)
    }

    func reset() {
        resetCount += 1
    }

    func releaseInterruptedScan() {
        interruptedScanContinuation?.resume()
        interruptedScanContinuation = nil
    }

    func currentScanCount() -> Int {
        scanCount
    }

    func currentResetCount() -> Int {
        resetCount
    }

    private func result(id: String, input: Int64) -> LocalActivityScanResult {
        let tokens = LocalActivityTokenBreakdown(
            provider: .codex,
            inputTokens: input,
            cachedInputTokens: 0,
            outputTokens: 50,
            reasoningOutputTokens: 0
        )!
        return LocalActivityScanResult(
            requests: [
                LocalActivityRequest(
                    id: id,
                    provider: .codex,
                    occurredAt: .now,
                    modelID: "gpt-test",
                    tokens: tokens
                ),
            ],
            cursors: [],
            status: .readable
        )
    }
}
