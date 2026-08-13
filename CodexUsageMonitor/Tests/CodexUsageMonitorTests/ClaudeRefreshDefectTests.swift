import Foundation
import XCTest
@testable import CodexUsageMonitor

/// Reproduces the three defects that made the Refresh button appear to do
/// nothing — no reading, no Keychain dialog, no message — while running the
/// CLI probe seconds later worked:
///
/// - **D1** the 429 back-off gated the whole tier-1 attempt regardless of
///   refresh reason, so an explicit press never reached the Keychain.
/// - **D2** `refreshNow` returned early whenever a refresh was already in
///   flight, silently discarding the user's press.
/// - **D3** the CLI probe runs in its own process with no back-off state, so it
///   reached the Keychain where the app would not — the visible symptom.
final class ClaudeRefreshDefectTests: XCTestCase {
    // MARK: D1 — an explicit refresh must not be gated by the back-off

    func testUserInitiatedRefreshIsAttemptedDuringBackOff() async {
        let source = SpyOAuthSource()
        source.outcome = .rateLimited
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            now: { Date(timeIntervalSince1970: 0) }
        )

        _ = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(source.fetchCount, 1)

        // Still inside the back-off window. An automatic read must stay away
        // from the endpoint; the user's press must still be attempted.
        _ = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(source.fetchCount, 1, "a scheduled read must respect the back-off")

        _ = await collector.refresh(reason: .userInitiated)
        XCTAssertEqual(source.fetchCount, 2, "an explicit refresh must still reach the source")
    }

    func testUserInitiatedRefreshUsesPromptingPolicyDuringBackOff() async {
        let source = SpyOAuthSource()
        source.outcome = .rateLimited
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            now: { Date(timeIntervalSince1970: 0) }
        )

        _ = await collector.refresh(reason: .scheduled)
        _ = await collector.refresh(reason: .userInitiated)

        // The press is what earns the right to raise the Keychain dialog. If the
        // bypassing read used `.never`, the dialog could never appear.
        XCTAssertEqual(source.policies, [.never, .userInitiatedOnly])
    }

    func testRepeatedBypassesAreBoundedAndExplained() async {
        let source = SpyOAuthSource()
        source.outcome = .rateLimited
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            now: { clock.now }
        )

        _ = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(source.fetchCount, 1)

        _ = await collector.refresh(reason: .userInitiated)
        XCTAssertEqual(source.fetchCount, 2)

        // A second press moments later must not compound the rate limit, and
        // must say so rather than appearing to do nothing.
        clock.now = Date(timeIntervalSince1970: 5)
        let refused = await collector.refresh(reason: .userInitiated)
        XCTAssertEqual(source.fetchCount, 2, "a press inside the minimum interval must not re-hit the endpoint")
        XCTAssertFalse(refused.warnings.isEmpty, "a refresh that does nothing must say why")

        // Once the minimum interval has passed, a press is attempted again.
        clock.now = Date(timeIntervalSince1970: 120)
        _ = await collector.refresh(reason: .userInitiated)
        XCTAssertEqual(source.fetchCount, 3)
    }

    func testDegradedRefreshExplainsWhyItIsNotLive() async {
        let source = SpyOAuthSource()
        source.outcome = .keychainDenied
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            now: { Date(timeIntervalSince1970: 0) }
        )

        let result = await collector.refresh(reason: .userInitiated)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(
            result.warnings.contains { $0.localizedCaseInsensitiveContains("keychain") },
            "a denied Keychain read must be named, not reported as a generic outage"
        )
    }

    // MARK: D2 — an explicit refresh must never be silently discarded

    @MainActor
    func testUserInitiatedRefreshIsNotDroppedWhileAScheduledReadIsInFlight() async {
        let collector = GatedCollector()
        let monitor = ClaudeUsageMonitor(collector: collector, pollInterval: .seconds(3_600))

        // Start a scheduled refresh and hold it inside the collector, exactly as
        // a slow network read holds `isRefreshing` across its await.
        let scheduled = Task { await monitor.refreshNow(reason: .scheduled) }
        await collector.waitUntilFirstCallStarted()

        let pressed = Task { await monitor.refreshNow(reason: .userInitiated) }
        await collector.releaseFirstCall()
        _ = await scheduled.value
        _ = await pressed.value

        let reasons = await collector.observedReasons
        XCTAssertTrue(
            reasons.contains(where: { $0 == .userInitiated }),
            "the press must perform its own read rather than being dropped"
        )
    }

    @MainActor
    func testAutomaticRefreshStillCoalescesWithWorkAlreadyRunning() async {
        let collector = GatedCollector()
        let monitor = ClaudeUsageMonitor(collector: collector, pollInterval: .seconds(3_600))

        let first = Task { await monitor.refreshNow(reason: .scheduled) }
        await collector.waitUntilFirstCallStarted()
        let second = Task { await monitor.refreshNow(reason: .scheduled) }
        await collector.releaseFirstCall()
        _ = await first.value
        _ = await second.value

        let count = await collector.callCount
        XCTAssertEqual(count, 1, "a scheduled read must not queue behind another one")
    }

    // MARK: Fixtures

    private static func absentFile() -> URL {
        URL(fileURLWithPath: "/private/tmp")
            .appendingPathComponent("absent-\(UUID().uuidString).json")
    }
}

/// A clock a test can advance across the collector's `@Sendable` boundary.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date) { _now = now }
    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }
}

/// Drives a real `ClaudeOAuthUsageSource` through its existing injection
/// points, so the test observes the production code path rather than a stand-in
/// for it. Records every prompt policy the credential store was asked for and
/// every HTTP attempt.
private final class SpyOAuthSource: @unchecked Sendable {
    enum Outcome {
        case rateLimited
        case keychainDenied
        case success
    }

    private let lock = NSLock()
    private var _policies: [KeychainPromptPolicy] = []
    private var _httpAttempts = 0
    private var _outcome: Outcome = .rateLimited

    var outcome: Outcome {
        get { lock.withLock { _outcome } }
        set { lock.withLock { _outcome = newValue } }
    }
    /// Attempts that reached the credential store — what "the button did
    /// something" actually means.
    var fetchCount: Int { lock.withLock { _policies.count } }
    var policies: [KeychainPromptPolicy] { lock.withLock { _policies } }
    var httpAttempts: Int { lock.withLock { _httpAttempts } }

    private func record(_ policy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
        lock.withLock { _policies.append(policy) }
        if outcome == .keychainDenied { throw ClaudeCredentialError.accessDenied }
        return ClaudeOAuthCredential(
            accessToken: "test-token",
            refreshToken: nil,
            expiresAt: nil,
            scopes: ["user:profile"],
            subscriptionType: "pro"
        )
    }

    private func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
        lock.withLock { _httpAttempts += 1 }
        let url = request.url!
        switch outcome {
        case .rateLimited:
            return (Data(), HTTPURLResponse(
                url: url, statusCode: 429, httpVersion: nil,
                headerFields: ["Retry-After": "900"]
            )!)
        case .success:
            let body = Data(#"{"five_hour":{"utilization":11},"seven_day":{"utilization":2}}"#.utf8)
            return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        case .keychainDenied:
            throw ClaudeOAuthError.transportError
        }
    }

    var asSource: ClaudeOAuthUsageSource {
        ClaudeOAuthUsageSource(
            credentialStore: RecordingStore(record: { try self.record($0) }),
            requestExecutor: { try self.respond($0) }
        )
    }

    private struct RecordingStore: ClaudeCredentialProviding {
        let record: @Sendable (KeychainPromptPolicy) throws -> ClaudeOAuthCredential
        func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
            try record(promptPolicy)
        }
    }
}

/// Lets a test hold one refresh inside the collector while another arrives.
private actor GatedCollector: ClaudeUsageCollecting {
    private(set) var observedReasons: [ClaudeRefreshReason] = []
    private(set) var callCount = 0
    private var started: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    private var firstCallRunning = false

    func waitUntilFirstCallStarted() async {
        if firstCallRunning { return }
        await withCheckedContinuation { started = $0 }
    }

    func releaseFirstCall() {
        release?.resume()
        release = nil
    }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        callCount += 1
        observedReasons.append(reason)
        if callCount == 1 {
            firstCallRunning = true
            started?.resume()
            started = nil
            await withCheckedContinuation { release = $0 }
        }
        return ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: "pro",
                fiveHour: ClaudeLimitWindow(usedPercent: 10, resetsAt: nil),
                sevenDay: nil,
                scopedWindows: [],
                extraUsage: nil,
                source: .oauth,
                capturedAt: .now,
                schemaVersion: 1
            ),
            delivery: .live,
            warnings: []
        )
    }
}
