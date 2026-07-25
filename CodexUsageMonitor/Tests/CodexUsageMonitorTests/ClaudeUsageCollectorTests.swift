import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageCollectorTests: XCTestCase {
    private var tempDirectory: URL!
    private var cacheFileURL: URL!
    private var statusLineFileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageCollectorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        cacheFileURL = tempDirectory.appendingPathComponent("cache.json")
        statusLineFileURL = tempDirectory.appendingPathComponent("statusline.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testAdaptStatusLineSnapshotMapsBothWindows() {
        let statusLineSnapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: ClaudeRateLimitWindow(usedPercentage: 12.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: ClaudeRateLimitWindow(usedPercentage: 44.0, resetsAt: Date(timeIntervalSince1970: 1_800_500_000))
        )

        let adapted = adaptStatusLineSnapshot(statusLineSnapshot)

        XCTAssertEqual(adapted.source, .statusLine)
        XCTAssertEqual(adapted.fiveHour?.usedPercent, 12.0)
        XCTAssertEqual(adapted.sevenDay?.usedPercent, 44.0)
        XCTAssertEqual(adapted.capturedAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testRefreshReturnsLiveWhenOAuthSucceeds() async throws {
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: ["user:profile"], subscriptionType: "pro")
            )),
            requestExecutor: { _ in (Self.encodedOAuthFixture(fiveHour: 10.0), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: ClaudeUsageCache(fileURL: cacheFileURL)
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .live)
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 10.0)
    }

    func testRefreshFallsBackToStatusLineWhenOAuthFails() async throws {
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 7.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: statusLineFileURL)
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not be called"); return (Data(), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: ClaudeUsageCache(fileURL: cacheFileURL)
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .passiveSnapshot)
        XCTAssertEqual(presentation.snapshot.source, .statusLine)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 7.0)
    }

    func testRefreshFallsBackToCacheWhenOAuthAndStatusLineBothUnavailable() async throws {
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        cache.save(ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 55.0, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil, source: .oauth, capturedAt: .now, schemaVersion: 1
        ))
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not be called"); return (Data(), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .cached)
        // Cache preserves the ORIGINAL source (.oauth), not .cache — the
        // whole point of tracking source and delivery separately.
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 55.0)
    }

    func testSuccessfulOAuthRefreshUpdatesCache() async throws {
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: ["user:profile"], subscriptionType: "pro")
            )),
            requestExecutor: { _ in (Self.encodedOAuthFixture(fiveHour: 21.0), Self.httpResponse(200)) }
        )
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        _ = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(cache.load()?.snapshot.fiveHour?.usedPercent, 21.0)
    }

    private static func encodedOAuthFixture(fiveHour: Double) -> Data {
        Data("""
        {"five_hour": {"utilization": \(fiveHour), "resets_at": "2026-07-20T14:50:00.630618+00:00"}, "seven_day": null}
        """.utf8)
    }

    func testRateLimitBacksOffOAuthUntilRetryAfter() async throws {
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        cache.save(ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 40, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil, source: .oauth, capturedAt: .now, schemaVersion: 1
        ))

        let calls = CallCounter()
        let clock = NowBox(Date(timeIntervalSince1970: 1_000_000))
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: ["user:profile"], subscriptionType: "pro")
            )),
            requestExecutor: { _ in
                calls.increment()
                return (Data(), Self.httpResponse(429, headers: ["Retry-After": "600"]))
            },
            now: { clock.value }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache,
            now: { clock.value }
        )

        // 1) 429 -> back-off recorded, serves the cache.
        let first = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(first.delivery, .cached)
        XCTAssertEqual(calls.count, 1)

        // 2) still within the back-off window -> OAuth is not hit again.
        _ = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(calls.count, 1, "OAuth must not be retried during the Retry-After back-off")

        // 3) after Retry-After passes -> OAuth resumes.
        clock.value = clock.value.addingTimeInterval(601)
        _ = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(calls.count, 2, "OAuth resumes once the back-off window elapses")
    }

    private static func httpResponse(_ status: Int, headers: [String: String]? = nil) -> URLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, statusCode: status, httpVersion: nil, headerFields: headers)!
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func increment() { lock.withLock { value += 1 } }
}

private final class NowBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Date
    init(_ date: Date) { stored = date }
    var value: Date {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private struct FakeCredentialStore: ClaudeCredentialProviding {
    let result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    /// Records the policy it was asked with, so tests can assert that an
    /// automatic refresh never requests interaction.
    let policyRecorder: PolicyRecorder?

    init(result: Result<ClaudeOAuthCredential, ClaudeCredentialError>, policyRecorder: PolicyRecorder? = nil) {
        self.result = result
        self.policyRecorder = policyRecorder
    }

    func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
        policyRecorder?.record(promptPolicy)
        switch result {
        case .success(let credential): return credential
        case .failure(let error): throw error
        }
    }
}

final class PolicyRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [KeychainPromptPolicy] = []
    var recorded: [KeychainPromptPolicy] { lock.withLock { values } }
    func record(_ policy: KeychainPromptPolicy) { lock.withLock { values.append(policy) } }
}

/// The safety property this whole policy exists for: an automatic refresh
/// must be structurally unable to raise a Keychain dialog, and only an
/// explicit user action may.
final class ClaudeCollectorPromptPolicyTests: XCTestCase {
    private func makeCollector(recorder: PolicyRecorder) -> ClaudeUsageCollector {
        let store = FakeCredentialStore(
            result: .success(
                ClaudeOAuthCredential(
                    accessToken: "t", refreshToken: nil, expiresAt: nil,
                    scopes: ["user:profile"], subscriptionType: "pro"
                )
            ),
            policyRecorder: recorder
        )
        // Fail the network so the collector falls through; we only care which
        // policy reached the credential read.
        let source = ClaudeOAuthUsageSource(
            credentialStore: store,
            requestExecutor: { _ in throw URLError(.notConnectedToInternet) }
        )
        return ClaudeUsageCollector(
            oauthSource: source,
            statusLineReader: ClaudeRateLimitSnapshotReader(
                fileURL: URL(fileURLWithPath: "/nonexistent/claude-rate-limits.json")
            ),
            cache: ClaudeUsageCache(fileURL: URL(fileURLWithPath: "/nonexistent/cache.json"))
        )
    }

    func testScheduledRefreshNeverRequestsInteraction() async {
        let recorder = PolicyRecorder()
        _ = await makeCollector(recorder: recorder).refresh(reason: .scheduled)
        XCTAssertEqual(recorder.recorded, [.never])
    }

    func testMenuOpenedRefreshNeverRequestsInteraction() async {
        let recorder = PolicyRecorder()
        _ = await makeCollector(recorder: recorder).refresh(reason: .menuOpened)
        XCTAssertEqual(recorder.recorded, [.never])
    }

    func testAppLaunchRefreshNeverRequestsInteraction() async {
        let recorder = PolicyRecorder()
        _ = await makeCollector(recorder: recorder).refresh(reason: .appLaunch)
        XCTAssertEqual(recorder.recorded, [.never])
    }

    func testUserInitiatedRefreshMayPrompt() async {
        let recorder = PolicyRecorder()
        _ = await makeCollector(recorder: recorder).refresh(reason: .userInitiated)
        XCTAssertEqual(recorder.recorded, [.userInitiatedOnly])
    }
}

/// Tier 3 outranks tier 4 only because a statusLine capture is normally
/// fresher than the cache. When it is not, ranking it higher shows the user
/// worse data than we already hold.
final class ClaudeCollectorFreshnessTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeCollectorFreshness-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// OAuth is unavailable, a 47h-old statusLine snapshot exists, and the
    /// cache holds a recent OAuth read — the cache must win.
    func testStaleStatusLineLosesToFresherCache() async throws {
        let statusLineURL = directory.appendingPathComponent("rate-limits.json")
        let cacheURL = directory.appendingPathComponent("cache.json")
        let old = Date().addingTimeInterval(-47 * 3600)
        try Data("""
        {"schemaVersion":1,"capturedAt":\(old.timeIntervalSince1970),"fiveHour":{"usedPercentage":5.0,"resetsAt":\(Date().addingTimeInterval(3600).timeIntervalSince1970)}}
        """.utf8).write(to: statusLineURL)

        let cache = ClaudeUsageCache(fileURL: cacheURL)
        cache.save(
            ClaudeUsageSnapshot(
                planHint: "pro",
                fiveHour: ClaudeLimitWindow(usedPercent: 44, resetsAt: nil),
                sevenDay: ClaudeLimitWindow(usedPercent: 28, resetsAt: nil),
                scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now, schemaVersion: 1
            )
        )

        let collector = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(
                credentialStore: FakeCredentialStore(result: .failure(.notFound)),
                requestExecutor: { _ in throw URLError(.notConnectedToInternet) }
            ),
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineURL),
            cache: cache
        )

        let result = await collector.refresh(reason: .scheduled)

        XCTAssertEqual(result.delivery, .cached, "the fresher cached OAuth read must win")
        XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, 44)
        XCTAssertEqual(cache.load()?.snapshot.fiveHour?.usedPercent, 44, "and must not be clobbered")
    }

    /// The normal case must be unaffected: a fresh statusLine capture still
    /// outranks an older cache.
    func testFreshStatusLineStillWinsOverOlderCache() async throws {
        let statusLineURL = directory.appendingPathComponent("rate-limits.json")
        let cacheURL = directory.appendingPathComponent("cache.json")
        try Data("""
        {"schemaVersion":1,"capturedAt":\(Date().timeIntervalSince1970),"fiveHour":{"usedPercentage":7.0,"resetsAt":\(Date().addingTimeInterval(3600).timeIntervalSince1970)}}
        """.utf8).write(to: statusLineURL)

        let cache = ClaudeUsageCache(fileURL: cacheURL)
        cache.save(
            ClaudeUsageSnapshot(
                planHint: "pro",
                fiveHour: ClaudeLimitWindow(usedPercent: 44, resetsAt: nil),
                sevenDay: nil, scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now.addingTimeInterval(-10 * 3600), schemaVersion: 1
            )
        )

        let collector = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(
                credentialStore: FakeCredentialStore(result: .failure(.notFound)),
                requestExecutor: { _ in throw URLError(.notConnectedToInternet) }
            ),
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineURL),
            cache: cache
        )

        let result = await collector.refresh(reason: .scheduled)

        XCTAssertEqual(result.delivery, .passiveSnapshot)
        XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, 7)
    }
}
