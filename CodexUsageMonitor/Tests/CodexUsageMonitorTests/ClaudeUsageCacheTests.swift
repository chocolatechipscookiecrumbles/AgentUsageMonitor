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
