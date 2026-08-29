import XCTest
@testable import CodexUsageMonitor

private final class SpyCredentialProvider: ClaudeSelfIssuedCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    private var loads = 0
    private var deletes = 0
    private var policies: [KeychainPromptPolicy] = []

    init(_ result: Result<ClaudeOAuthCredential, ClaudeCredentialError>) {
        self.result = result
    }

    var loadCount: Int { lock.withLock { loads } }
    var seenPolicies: [KeychainPromptPolicy] { lock.withLock { policies } }
    var deleteCount: Int { lock.withLock { deletes } }

    func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
        lock.withLock { loads += 1; policies.append(promptPolicy) }
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

    func testMissingSelectedMethodDoesNotReadOtherMethod() {
        let selfIssued = SpyCredentialProvider(.failure(.notFound))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let recorder = ClaudeEffectiveMethodRecorder()
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser, selfIssued: selfIssued, borrowed: borrowed, recorder: recorder
        )

        XCTAssertThrowsError(try store.resolve()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
        XCTAssertEqual(borrowed.loadCount, 0, "borrowed Keychain access must be an explicit user choice")
        XCTAssertNil(recorder.effectiveMethod)
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

    func testSelectedMethodFailureIsSurfaced() {
        let borrowed = SpyCredentialProvider(.failure(.accessDenied))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: borrowed
        )

        XCTAssertThrowsError(try store.resolve()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
        XCTAssertEqual(borrowed.loadCount, 0)
    }

    func testInvalidateSelfIssuedDeletesItWithoutReadingBorrowed() {
        let selfIssued = SpyCredentialProvider(.success(credential("self-issued")))
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser, selfIssued: selfIssued, borrowed: borrowed
        )

        store.invalidateSelfIssued()

        XCTAssertEqual(selfIssued.deleteCount, 1)
        XCTAssertThrowsError(try store.resolve())
        XCTAssertEqual(borrowed.loadCount, 0)
    }

    func testPromptPolicyIsForwardedToTheUnderlyingProvider() throws {
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .claudeCodeCredentials,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: borrowed
        )

        _ = try store.resolve(promptPolicy: .userInitiatedOnly)

        XCTAssertEqual(borrowed.seenPolicies, [.userInitiatedOnly])
    }

    func testDefaultResolveNeverRequestsInteraction() throws {
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .claudeCodeCredentials,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: borrowed
        )

        _ = try store.resolve()

        XCTAssertEqual(borrowed.seenPolicies, [.never], "the default must never be able to prompt")
    }

    func testFailedSelectedMethodDoesNotForwardPolicyToOtherMethod() {
        let borrowed = SpyCredentialProvider(.success(credential("borrowed")))
        let store = ClaudeCompositeCredentialStore(
            selectedMethod: .browser,
            selfIssued: SpyCredentialProvider(.failure(.notFound)),
            borrowed: borrowed
        )

        XCTAssertThrowsError(try store.resolve(promptPolicy: .never))

        XCTAssertEqual(borrowed.seenPolicies, [])
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
