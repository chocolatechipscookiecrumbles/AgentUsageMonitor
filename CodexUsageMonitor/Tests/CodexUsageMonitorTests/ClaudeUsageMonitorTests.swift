import XCTest
@testable import CodexUsageMonitor

/// Stands in for ClaudeUsageCollector so the monitor can be driven without
/// touching the Keychain, the network, or the filesystem.
private final class FakeCollector: ClaudeUsageCollecting, @unchecked Sendable {
    private let lock = NSLock()
    private var result: ClaudeUsagePresentation
    private var reasons: [ClaudeRefreshReason] = []

    init(_ result: ClaudeUsagePresentation) {
        self.result = result
    }

    var seenReasons: [ClaudeRefreshReason] { lock.withLock { reasons } }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        lock.withLock {
            reasons.append(reason)
            return result
        }
    }
}

private func presentation(
    delivery: ClaudeUsageDelivery,
    source: ClaudeUsageSource = .oauth,
    fiveHour: Double? = 10,
    warnings: [String] = []
) -> ClaudeUsagePresentation {
    ClaudeUsagePresentation(
        snapshot: ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: fiveHour.map { ClaudeLimitWindow(usedPercent: $0, resetsAt: nil) },
            sevenDay: nil,
            scopedWindows: [],
            extraUsage: nil,
            source: source,
            capturedAt: .now,
            schemaVersion: 1
        ),
        delivery: delivery,
        warnings: warnings
    )
}

@MainActor
final class ClaudeUsageMonitorTests: XCTestCase {
    func testRefreshPublishesLivePresentationFromCollector() async {
        let collector = FakeCollector(presentation(delivery: .live))
        let monitor = ClaudeUsageMonitor(collector: collector)

        await monitor.refreshNow(reason: .userInitiated)

        guard case .available(let published) = monitor.state else {
            return XCTFail("expected .available")
        }
        XCTAssertEqual(published.delivery, .live)
        XCTAssertEqual(published.snapshot.source, .oauth)
        XCTAssertEqual(published.snapshot.fiveHour?.usedPercent, 10)
    }

    func testDeliveryIsPreservedSeparatelyFromSource() async {
        let collector = FakeCollector(presentation(delivery: .cached, source: .statusLine))
        let monitor = ClaudeUsageMonitor(collector: collector)

        await monitor.refreshNow(reason: .scheduled)

        guard case .available(let published) = monitor.state else {
            return XCTFail("expected .available")
        }
        XCTAssertEqual(published.delivery, .cached, "cached delivery must not be reported as live")
        XCTAssertEqual(published.snapshot.source, .statusLine, "origin is independent of freshness")
    }

    /// Gate criterion #5: no usable source must be an explicit unavailable
    /// state, never a zeroed snapshot presented as a quota.
    func testNoUsableSourcePublishesUnavailable() async {
        let empty = ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now, schemaVersion: 1
            ),
            delivery: .cached,
            warnings: ["No Claude usage source is currently available."]
        )
        let monitor = ClaudeUsageMonitor(collector: FakeCollector(empty))

        await monitor.refreshNow(reason: .scheduled)

        guard case .unavailable(let reason) = monitor.state else {
            return XCTFail("expected .unavailable, got \(monitor.state)")
        }
        XCTAssertEqual(reason, "No Claude usage source is currently available.")
    }

    func testUserInitiatedRefreshPassesUserInitiatedReason() async {
        let collector = FakeCollector(presentation(delivery: .live))
        let monitor = ClaudeUsageMonitor(collector: collector)

        await monitor.refreshNow(reason: .userInitiated)

        XCTAssertEqual(collector.seenReasons, [.userInitiated])
    }

    func testMenuOpenedRefreshPassesMenuOpenedReason() async {
        let collector = FakeCollector(presentation(delivery: .live))
        let monitor = ClaudeUsageMonitor(collector: collector)

        await monitor.refreshNow(reason: .menuOpened)

        XCTAssertEqual(collector.seenReasons, [.menuOpened])
    }

    func testStartRefreshesImmediatelyWithAppLaunchReason() async {
        let collector = FakeCollector(presentation(delivery: .live))
        let monitor = ClaudeUsageMonitor(collector: collector, pollInterval: .seconds(600))

        monitor.start()
        for _ in 0..<500 where collector.seenReasons.isEmpty {
            await Task.yield()
        }
        monitor.stop()

        XCTAssertEqual(collector.seenReasons.first, .appLaunch, "app launch must not wait a full interval")
    }

    func testStopCancelsPolling() async throws {
        let collector = FakeCollector(presentation(delivery: .live))
        let monitor = ClaudeUsageMonitor(collector: collector, pollInterval: .milliseconds(20))

        monitor.start()
        monitor.stop()
        let countAfterStop = collector.seenReasons.count
        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(collector.seenReasons.count, countAfterStop, "no polling after stop")
    }

    /// The cadence is network-appropriate now that a refresh can reach OAuth —
    /// the previous 30s local-file poll would mean an API call every 30s.
    func testDefaultPollIntervalIsNetworkAppropriate() {
        XCTAssertGreaterThanOrEqual(ClaudeUsageMonitor.defaultPollInterval, .seconds(600))
    }
}
