import XCTest
@testable import CodexUsageMonitor

private final class SpyCredentialProvider: ClaudeSelfIssuedCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    private var loads = 0
    private var deletes = 0

    init(_ result: Result<ClaudeOAuthCredential, ClaudeCredentialError>) {
        self.result = result
    }

    var loadCount: Int { lock.withLock { loads } }
    var deleteCount: Int { lock.withLock { deletes } }

    func loadCredential() throws -> ClaudeOAuthCredential {
        lock.withLock { loads += 1 }
        switch lock.withLock({ result }) {
        case .success(let credential): return credential
        case .failure(let error): throw error
        }
    }

    func delete() {
        lock.withLock {
            deletes += 1
            result = .failure(.notFound)
        }
    }
}

private func credential(_ token: String) -> ClaudeOAuthCredential {
    ClaudeOAuthCredential(
        accessToken: token, refreshToken: nil, expiresAt: nil,
        scopes: ["user:profile"], subscriptionType: "pro"
    )
}

final class ClaudeCompositeCredentialStoreTests: XCTestCase {
    func testBrowserMethodPrefersSelfIssuedAndLeavesKeychainUntouched() throws {
        let selfIssued = SpyCredentialProvider(.success(credential("self-issued")))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser, selfIssued: selfIssued, borrowed: borrowed
        )

        let resolution = try store.resolve()

        XCTAssertEqual(resolution.credential.accessToken, "self-issued")
        XCTAssertEqual(resolution.method, .browser)
        XCTAssertEqual(borrowed.loadCount, 0, "the Keychain item must not be read when browser method is selected")
    }

    func testClaudeCodeCredentialsMethodPrefersKeychainAndLeavesSelfIssuedUntouched() throws {
        let selfIssued = SpyCredentialProvider(.success(credential("self-issued")))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .claudeCodeCredentials, selfIssued: selfIssued, borrowed: borrowed
        )

        let resolution = try store.resolve()

        XCTAssertEqual(resolution.credential.accessToken, "borrowed")
        XCTAssertEqual(resolution.method, .claudeCodeCredentials)
        XCTAssertEqual(selfIssued.loadCount, 0)
    }

    func testFallsBackToOtherMethodAndReportsEffectiveMethod() throws {
        let selfIssued = SpyCredentialProvider(.failure(.notFound))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let recorder = ClaudeEffectiveMethodRecorder()
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser, selfIssued: selfIssued, borrowed: borrowed, recorder: recorder
        )

        let resolution = try store.resolve()

        XCTAssertEqual(resolution.credential.accessToken, "borrowed")
        XCTAssertEqual(resolution.method, .claudeCodeCredentials, "the degrade must be reported, not masked")
        XCTAssertEqual(recorder.effectiveMethod, .claudeCodeCredentials)
    }

    func testRecordsSelectedMethodWhenNoDegradeHappened() throws {
        let recorder = ClaudeEffectiveMethodRecorder()
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser,
            selfIssued: SpyCredentialProvider(.success(credential("self-issued"))),
            borrowed: SpyCredentialProvider(.success(credential("borrowed"))),
            recorder: recorder
        )

        _ = try store.resolve()

        XCTAssertEqual(recorder.effectiveMethod, .browser)
    }

    func testThrowsWhenBothMethodsFail() {
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: SpyCredentialProvider(.failure(.accessDenied))
        )

        XCTAssertThrowsError(try store.resolve()) { error in
            // Surfaces the *selected* method's failure so the message matches
            // what the user chose; the collector then degrades to tier 2/3/4.
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testInvalidateSelfIssuedDeletesItAndFallsBackToBorrowed() throws {
        let selfIssued = SpyCredentialProvider(.success(credential("self-issued")))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser, selfIssued: selfIssued, borrowed: borrowed
        )

        store.invalidateSelfIssued()
        let resolution = try store.resolve()

        XCTAssertEqual(selfIssued.deleteCount, 1)
        XCTAssertEqual(resolution.credential.accessToken, "borrowed")
        XCTAssertEqual(resolution.method, .claudeCodeCredentials)
    }

    func testLoadCredentialConformanceDelegatesToResolve() throws {
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .claudeCodeCredentials,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: SpyCredentialProvider(.success(credential("borrowed")))
        )

        XCTAssertEqual(try store.loadCredential().accessToken, "borrowed")
    }
}
