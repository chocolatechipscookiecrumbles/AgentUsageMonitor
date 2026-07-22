import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageCacheTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("last-known-good.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func sampleSnapshot(source: ClaudeUsageSource = .oauth) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: source, capturedAt: Date(timeIntervalSince1970: 1_700_000_000), schemaVersion: 1
        )
    }

    func testLoadReturnsNilWhenNoCacheExists() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        XCTAssertNil(cache.load())
    }

    func testSaveThenLoadRoundTrips() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot())

        let loaded = cache.load()

        XCTAssertEqual(loaded?.snapshot, sampleSnapshot())
    }

    func testSavePreservesOriginalSourceThroughMultipleSaves() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot(source: .oauth))
        cache.save(sampleSnapshot(source: .statusLine))

        XCTAssertEqual(cache.load()?.snapshot.source, .statusLine)
    }

    func testFileHasOwnerOnlyPermissions() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot())

        let mode = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o600)
    }

    func testLoadReturnsNilForCorruptedFile() throws {
        try Data("not json".utf8).write(to: fileURL)
        let cache = ClaudeUsageCache(fileURL: fileURL)

        XCTAssertNil(cache.load())
    }
}

/// The cache is last-known-**good**. A degraded refresh must not replace a
/// fresh result with an older one — the bug that left a 47-hour-old
/// statusLine capture sitting on top of a current OAuth read.
final class ClaudeUsageCacheFreshnessTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageCacheFreshness-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("cache.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func snapshot(_ source: ClaudeUsageSource, capturedAt: Date, fiveHour: Double) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: fiveHour, resetsAt: nil),
            sevenDay: nil,
            scopedWindows: [],
            extraUsage: nil,
            source: source,
            capturedAt: capturedAt,
            schemaVersion: 1
        )
    }

    func testOlderSnapshotDoesNotOverwriteNewerOne() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        let fresh = snapshot(.oauth, capturedAt: .now, fiveHour: 44)
        let stale = snapshot(.statusLine, capturedAt: .now.addingTimeInterval(-47 * 3600), fiveHour: 5)

        cache.save(fresh)
        cache.save(stale)

        let loaded = cache.load()
        XCTAssertEqual(loaded?.snapshot.source, .oauth, "a 47h-old capture must not clobber a current one")
        XCTAssertEqual(loaded?.snapshot.fiveHour?.usedPercent, 44)
    }

    func testNewerSnapshotDoesOverwriteOlderOne() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(snapshot(.statusLine, capturedAt: .now.addingTimeInterval(-3600), fiveHour: 5))
        cache.save(snapshot(.oauth, capturedAt: .now, fiveHour: 44))

        XCTAssertEqual(cache.load()?.snapshot.source, .oauth)
        XCTAssertEqual(cache.load()?.snapshot.fiveHour?.usedPercent, 44)
    }

    func testEqualTimestampsStillWrite() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        let stamp = Date()
        cache.save(snapshot(.statusLine, capturedAt: stamp, fiveHour: 5))
        cache.save(snapshot(.oauth, capturedAt: stamp, fiveHour: 44))

        XCTAssertEqual(cache.load()?.snapshot.source, .oauth, "a same-age richer read may replace")
    }

    func testFirstWriteAlwaysSucceeds() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(snapshot(.statusLine, capturedAt: .now.addingTimeInterval(-99 * 3600), fiveHour: 5))
        XCTAssertNotNil(cache.load(), "an empty cache accepts anything")
    }
}
