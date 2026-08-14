import Foundation
import XCTest
@testable import CodexUsageMonitor

/// Covers the delegated refresh: when the borrowed access token has expired,
/// ask **Claude Code** to renew its own credential rather than waiting for the
/// user to happen to run it.
///
/// Motivated by a real three-hour outage — a continuously running app produced
/// no Claude reading from 20:52:45Z until Claude Code rewrote its credential at
/// 23:51:51Z, while the Keychain grant was intact throughout. See
/// `docs/development/claude-keychain-grant-durability.md` (O7).
final class ClaudeDelegatedRefreshTests: XCTestCase {
    func testTouchIsAttemptedAndSuccessIsProvenByFingerprintChange() async {
        let harness = Harness()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 100))]
        let coordinator = harness.makeCoordinator()

        let outcome = await coordinator.attempt(reason: .userInitiated)

        XCTAssertEqual(outcome, .refreshed)
        XCTAssertEqual(harness.touchCount, 1)
    }

    func testUnchangedFingerprintIsReportedAsNotRefreshed() async {
        let harness = Harness()
        // Claude Code ran but renewed nothing: the credential is byte-identical.
        let same = ClaudeCredentialFingerprint(modifiedAt: .init(timeIntervalSince1970: 0))
        harness.fingerprints = [same, same]
        let coordinator = harness.makeCoordinator()

        let outcome = await coordinator.attempt(reason: .userInitiated)

        XCTAssertEqual(outcome, .notRefreshed)
        XCTAssertEqual(harness.touchCount, 1)
    }

    func testCooldownSuppressesARepeatAttempt() async {
        let harness = Harness()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 0))]
        let coordinator = harness.makeCoordinator()

        _ = await coordinator.attempt(reason: .userInitiated)
        XCTAssertEqual(harness.touchCount, 1)

        let second = await coordinator.attempt(reason: .userInitiated)
        XCTAssertEqual(second, .suppressedByCooldown)
        XCTAssertEqual(harness.touchCount, 1, "the CLI must not be run again inside the cooldown")

        harness.clock.now = harness.clock.now.addingTimeInterval(ClaudeDelegatedRefreshCoordinator.cooldown + 1)
        _ = await coordinator.attempt(reason: .userInitiated)
        XCTAssertEqual(harness.touchCount, 2, "the cooldown must expire")
    }

    func testMissingCLIIsReportedWithoutRunningAnything() async {
        let harness = Harness()
        harness.isCLIAvailable = false
        let coordinator = harness.makeCoordinator()

        let outcome = await coordinator.attempt(reason: .userInitiated)

        XCTAssertEqual(outcome, .cliUnavailable)
        XCTAssertEqual(harness.touchCount, 0)
    }

    func testTouchFailureIsReportedAndDoesNotClaimSuccess() async {
        let harness = Harness()
        harness.touchError = TouchFailure()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 0))]
        let coordinator = harness.makeCoordinator()

        let outcome = await coordinator.attempt(reason: .userInitiated)

        XCTAssertEqual(outcome, .touchFailed)
    }

    /// The touch launches the provider CLI. That is a visible, user-facing side
    /// effect, so it must never happen on a timer.
    func testAutomaticReasonsNeverRunTheCLI() async {
        for reason in [ClaudeRefreshReason.appLaunch, .scheduled, .menuOpened] {
            let harness = Harness()
            harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                    .init(modifiedAt: .init(timeIntervalSince1970: 100))]
            let coordinator = harness.makeCoordinator()

            let outcome = await coordinator.attempt(reason: reason)

            XCTAssertEqual(outcome, .notPermittedForReason, "\(reason) must not launch the CLI")
            XCTAssertEqual(harness.touchCount, 0, "\(reason) must not launch the CLI")
        }
    }

    func testConcurrentAttemptsShareOneTouch() async {
        let harness = Harness()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 100))]
        harness.holdTouch = true
        let coordinator = harness.makeCoordinator()

        async let first = coordinator.attempt(reason: .userInitiated)
        await harness.waitUntilTouchStarted()
        async let second = coordinator.attempt(reason: .userInitiated)
        harness.releaseTouch()

        let outcomes = await [first, second]

        XCTAssertEqual(harness.touchCount, 1, "a second caller must join the in-flight touch")
        XCTAssertEqual(outcomes[0], outcomes[1], "both callers observe the same result")
    }

    // MARK: Collector integration

    func testUnauthorizedTriggersRenewalAndRetriesOnce() async {
        let source = ExpiringSource()
        let harness = Harness()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 100))]
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            delegatedRefresh: harness.makeCoordinator()
        )

        let result = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(harness.touchCount, 1, "a 401 must ask Claude Code to renew")
        XCTAssertEqual(source.attempts, 2, "the read must be retried exactly once after a renewal")
        XCTAssertEqual(result.delivery, .live)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testUnauthorizedWithoutRenewalDoesNotRetry() async {
        let source = ExpiringSource()
        let harness = Harness()
        // Claude Code ran but renewed nothing.
        let same = ClaudeCredentialFingerprint(modifiedAt: .init(timeIntervalSince1970: 0))
        harness.fingerprints = [same, same]
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            delegatedRefresh: harness.makeCoordinator()
        )

        let result = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(source.attempts, 1, "no renewal means no retry")
        XCTAssertNotEqual(result.delivery, .live)
        XCTAssertFalse(result.warnings.isEmpty, "the failure must still be stated")
    }

    func testScheduledRefreshNeverRenews() async {
        let source = ExpiringSource()
        let harness = Harness()
        harness.fingerprints = [.init(modifiedAt: .init(timeIntervalSince1970: 0)),
                                .init(modifiedAt: .init(timeIntervalSince1970: 100))]
        let collector = ClaudeUsageCollector(
            oauthSource: source.asSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: Self.absentFile()),
            cache: ClaudeUsageCache(fileURL: Self.absentFile()),
            delegatedRefresh: harness.makeCoordinator()
        )

        _ = await collector.refresh(reason: .scheduled)

        XCTAssertEqual(harness.touchCount, 0, "a timer must never launch the provider CLI")
    }

    private static func absentFile() -> URL {
        URL(fileURLWithPath: "/private/tmp").appendingPathComponent("absent-\(UUID().uuidString).json")
    }

    /// Returns 401 until the credential is renewed, then 200 — the shape of an
    /// expired borrowed access token.
    private final class ExpiringSource: @unchecked Sendable {
        private let lock = NSLock()
        private var _attempts = 0
        var attempts: Int { lock.withLock { _attempts } }

        var asSource: ClaudeOAuthUsageSource {
            ClaudeOAuthUsageSource(
                credentialStore: Store(),
                requestExecutor: { [self] request in
                    let attempt = lock.withLock { () -> Int in
                        _attempts += 1
                        return _attempts
                    }
                    let url = request.url!
                    if attempt == 1 {
                        return (Data(), HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!)
                    }
                    let body = Data(#"{"five_hour":{"utilization":9},"seven_day":{"utilization":3}}"#.utf8)
                    return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
            )
        }

        private struct Store: ClaudeCredentialProviding {
            func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
                ClaudeOAuthCredential(
                    accessToken: "t", refreshToken: nil, expiresAt: nil,
                    scopes: ["user:profile"], subscriptionType: "pro"
                )
            }
        }
    }

    // MARK: Harness

    private struct TouchFailure: Error {}

    private final class Harness: @unchecked Sendable {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_000))
        var isCLIAvailable = true
        var touchError: Error?
        var fingerprints: [ClaudeCredentialFingerprint] = []
        var holdTouch = false

        private let lock = NSLock()
        private var _touchCount = 0
        private var fingerprintIndex = 0
        private var started: CheckedContinuation<Void, Never>?
        private var release: CheckedContinuation<Void, Never>?

        var touchCount: Int { lock.withLock { _touchCount } }

        func waitUntilTouchStarted() async {
            await withCheckedContinuation { continuation in
                lock.withLock {
                    if _touchCount > 0 { continuation.resume() } else { started = continuation }
                }
            }
        }

        func releaseTouch() {
            lock.withLock {
                release?.resume()
                release = nil
            }
        }

        func makeCoordinator() -> ClaudeDelegatedRefreshCoordinator {
            ClaudeDelegatedRefreshCoordinator(
                isCLIAvailable: { [self] in isCLIAvailable },
                readFingerprint: { [self] in
                    lock.withLock {
                        defer { fingerprintIndex += 1 }
                        guard fingerprintIndex < fingerprints.count else { return fingerprints.last }
                        return fingerprints[fingerprintIndex]
                    }
                },
                touch: { [self] in
                    let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
                        _touchCount += 1
                        let pending = started
                        started = nil
                        return pending
                    }
                    continuation?.resume()
                    if holdTouch {
                        await withCheckedContinuation { c in lock.withLock { release = c } }
                    }
                    if let touchError { throw touchError }
                },
                now: { [self] in clock.now }
            )
        }
    }

    private final class MutableClock: @unchecked Sendable {
        private let lock = NSLock()
        private var _now: Date
        init(_ now: Date) { _now = now }
        var now: Date {
            get { lock.withLock { _now } }
            set { lock.withLock { _now = newValue } }
        }
    }
}
