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
                ClaudeOAuthCredential(accessToken: "t", scopes: ["user:profile"], subscriptionType: "pro")
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
                ClaudeOAuthCredential(accessToken: "t", scopes: ["user:profile"], subscriptionType: "pro")
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

    func testSilentCredentialFailurePreservesCachedQuotaAndCaptureTime() async throws {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        cache.save(ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 55, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: .oauth, capturedAt: capturedAt, schemaVersion: 1
        ))
        // A newer but empty passive payload must not hide the usable reading.
        try Data("{\"schemaVersion\":1,\"capturedAt\":1700000100}".utf8).write(to: statusLineFileURL)
        let recorder = PolicyRecorder()
        let collector = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(
                credentialStore: FakeCredentialStore(
                    result: .failure(.interactionNotAllowed), policyRecorder: recorder
                ),
                requestExecutor: { _ in
                    XCTFail("an unavailable credential must not make a request")
                    return (Data(), Self.httpResponse(200))
                }
            ),
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        let result = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(recorder.recorded, [.never])
        XCTAssertEqual(result.delivery, .cached)
        XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, 55)
        XCTAssertEqual(result.snapshot.capturedAt, capturedAt)
        XCTAssertEqual(result.warnings, ["Live fallback unavailable. Claude Code’s credential could not be read silently."])
    }

    func testEmptyOAuthResponseDoesNotReplaceUsableCachedQuota() async {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        cache.save(ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 55, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: .oauth, capturedAt: capturedAt, schemaVersion: 1
        ))
        let collector = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(
                credentialStore: FakeCredentialStore(result: .success(
                    ClaudeOAuthCredential(accessToken: "t", scopes: ["user:profile"], subscriptionType: "pro")
                )),
                requestExecutor: { _ in (Data("{}".utf8), Self.httpResponse(200)) }
            ),
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        let result = await collector.refresh(reason: .scheduled)

        XCTAssertEqual(result.delivery, .cached)
        XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, 55)
        XCTAssertEqual(result.snapshot.capturedAt, capturedAt)
        XCTAssertEqual(cache.load()?.snapshot, result.snapshot)
    }

    func testRejectedCredentialDoesNotRenewOrRetryDuringRefresh() async {
        for reason in [ClaudeRefreshReason.userInitiated, .scheduled] {
            let source = ExpiringSource()
            let collector = ClaudeUsageCollector(
                oauthSource: source.asSource,
                statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
                cache: ClaudeUsageCache(fileURL: cacheFileURL)
            )
            let result = await collector.refresh(reason: reason)
            XCTAssertEqual(source.attempts, 1, "a rejected credential falls through without CLI renewal")
            XCTAssertEqual(result.delivery, .cached)
            XCTAssertFalse(result.warnings.isEmpty)
        }
    }

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
                    accessToken: "t",
                    scopes: ["user:profile"], subscriptionType: "pro"
                )
            }
        }
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
                ClaudeOAuthCredential(accessToken: "t", scopes: ["user:profile"], subscriptionType: "pro")
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
                    accessToken: "t",
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

    func testUserInitiatedRefreshNeverRequestsInteraction() async {
        let recorder = PolicyRecorder()
        _ = await makeCollector(recorder: recorder).refresh(reason: .userInitiated)
        XCTAssertEqual(recorder.recorded, [.never])
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

    func testPassiveCaptureRetainsFinancialObservationWithoutCredentialRead() async throws {
        let observed = Date(timeIntervalSince1970: 1_700_000_000)
        let capture = observed.addingTimeInterval(3600)
        let statusLineURL = directory.appendingPathComponent("rate-limits.json")
        try Data("""
        {"schemaVersion":1,"capturedAt":\(capture.timeIntervalSince1970),"fiveHour":{"usedPercentage":7,"resetsAt":1800000000}}
        """.utf8).write(to: statusLineURL)
        let cache = ClaudeUsageCache(fileURL: directory.appendingPathComponent("cache.json"))
        cache.save(ClaudeUsageSnapshot(
            planHint: nil, fiveHour: ClaudeLimitWindow(usedPercent: 5, resetsAt: nil),
            sevenDay: nil, scopedWindows: [],
            extraUsage: ClaudeExtraUsage(isEnabled: true, monthlyLimit: 50, usedCredits: 12, currencyCode: "USD"),
            source: .oauth, capturedAt: observed, schemaVersion: 1
        ))
        let credentialReads = PolicyRecorder()
        let collector = ClaudeUsageCollector(
            oauthSource: ClaudeOAuthUsageSource(credentialStore: FakeCredentialStore(
                result: .failure(.notFound), policyRecorder: credentialReads),
                requestExecutor: { _ in XCTFail("Passive refresh must not request OAuth"); throw URLError(.badURL) }),
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineURL), cache: cache,
            now: { capture }
        )
        let result = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(result.delivery, .passiveSnapshot)
        XCTAssertEqual(result.snapshot.extraUsage?.usedCredits, 12)
        XCTAssertEqual(cache.load()?.snapshot.extraUsage?.usedCredits, 12)
        XCTAssertEqual(result.snapshot.extraUsageObservedAt, observed)
        XCTAssertEqual(cache.load()?.snapshot.extraUsageObservedAt, observed)
        let repeated = await collector.refresh(reason: .scheduled)
        XCTAssertEqual(repeated.snapshot.extraUsageObservedAt, observed)
        XCTAssertEqual(credentialReads.recorded, [])
    }

    func testFinancialOnlyOAuthSurvivesWithAndWithoutCachedQuota() async throws {
        let observed = Date(timeIntervalSince1970: 1_700_000_000)
        let quotaTime = observed.addingTimeInterval(-3600)
        for hasCachedQuota in [true, false] {
            let cache = ClaudeUsageCache(fileURL: directory.appendingPathComponent("financial-\(hasCachedQuota).json"))
            let statusURL = directory.appendingPathComponent("status-\(hasCachedQuota).json")
            if hasCachedQuota {
                cache.save(ClaudeUsageSnapshot(
                    planHint: nil, fiveHour: ClaudeLimitWindow(usedPercent: 25, resetsAt: nil),
                    sevenDay: nil, scopedWindows: [],
                    extraUsage: ClaudeExtraUsage(isEnabled: true, monthlyLimit: 50, usedCredits: 1, currencyCode: "USD"),
                    source: .oauth, capturedAt: quotaTime, schemaVersion: 1
                ))
            }
            let source = ClaudeOAuthUsageSource(
                credentialStore: FakeCredentialStore(result: .success(
                    ClaudeOAuthCredential(accessToken: "fixture", scopes: ["user:profile"], subscriptionType: nil)
                )),
                requestExecutor: { request in
                    (Data(#"{"extra_usage":{"is_enabled":true,"monthly_limit":50,"used_credits":12,"currency":"USD"}}"#.utf8),
                     HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }, now: { observed }
            )
            let collector = ClaudeUsageCollector(
                oauthSource: source, statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusURL),
                cache: cache, now: { observed }
            )
            let result = await collector.refresh(reason: .scheduled)
            XCTAssertEqual(result.delivery, .cached)
            XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, hasCachedQuota ? 25 : nil)
            XCTAssertEqual(result.snapshot.extraUsage?.usedCredits, 12)
            XCTAssertEqual(result.snapshot.extraUsageObservedAt, observed)
            XCTAssertEqual(cache.load()?.snapshot.extraUsage?.usedCredits, 12)
            if hasCachedQuota { XCTAssertEqual(result.snapshot.capturedAt, quotaTime) }

            let failingCollector = ClaudeUsageCollector(
                oauthSource: ClaudeOAuthUsageSource(credentialStore: FakeCredentialStore(result: .failure(.notFound))),
                statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusURL),
                cache: cache, now: { observed }
            )
            let fallback = await failingCollector.refresh(reason: .scheduled)
            XCTAssertEqual(fallback.snapshot.extraUsage?.usedCredits, 12)
            XCTAssertEqual(fallback.snapshot.extraUsageObservedAt, observed)
            XCTAssertEqual(fallback.snapshot.hasQuotaWindows, hasCachedQuota)

            try Data("""
            {"schemaVersion":1,"capturedAt":\(observed.addingTimeInterval(-30).timeIntervalSince1970),"fiveHour":{"usedPercentage":30,"resetsAt":1800000000}}
            """.utf8).write(to: statusURL)
            let passive = await failingCollector.refresh(reason: .scheduled)
            XCTAssertEqual(passive.delivery, .passiveSnapshot)
            XCTAssertEqual(passive.snapshot.fiveHour?.usedPercent, 30)
            XCTAssertEqual(passive.snapshot.extraUsage?.usedCredits, 12)
            XCTAssertEqual(passive.snapshot.extraUsageObservedAt, observed)
            XCTAssertEqual(cache.load()?.snapshot.fiveHour?.usedPercent, 30)
            XCTAssertEqual(cache.load()?.snapshot.capturedAt, observed.addingTimeInterval(-30))
            XCTAssertEqual(cache.load()?.snapshot.extraUsageObservedAt, observed)
        }
    }

    func testFinancialOnlyOAuthStillUsesUsablePassiveQuota() async throws {
        let observed = Date(timeIntervalSince1970: 1_700_000_000)
        let passiveTime = observed.addingTimeInterval(-180)
        let statusURL = directory.appendingPathComponent("financial-passive.json")
        try Data("""
        {"schemaVersion":1,"capturedAt":\(passiveTime.timeIntervalSince1970),"fiveHour":{"usedPercentage":30,"resetsAt":1800000000}}
        """.utf8).write(to: statusURL)
        let blockedDirectory = directory.appendingPathComponent("financial-passive-blocked")
        try Data().write(to: blockedDirectory)
        let cache = ClaudeUsageCache(fileURL: blockedDirectory.appendingPathComponent("cache.json"))
        let source = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "fixture", scopes: ["user:profile"], subscriptionType: nil)
            )),
            requestExecutor: { request in
                (Data(#"{"extra_usage":{"is_enabled":true,"monthly_limit":50,"used_credits":12,"currency":"USD"}}"#.utf8),
                 HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            },
            now: { observed }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: source,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusURL),
            cache: cache,
            now: { observed }
        )

        let result = await collector.refresh(reason: .scheduled)

        XCTAssertEqual(result.delivery, .passiveSnapshot)
        XCTAssertEqual(result.snapshot.capturedAt, passiveTime)
        XCTAssertEqual(result.snapshot.fiveHour?.usedPercent, 30)
        XCTAssertEqual(result.snapshot.extraUsage?.usedCredits, 12)
        XCTAssertEqual(result.snapshot.extraUsageObservedAt, observed)
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
