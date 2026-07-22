import XCTest
@testable import CodexUsageMonitor

/// Holds a sign-in operation open so the test can assert on the in-flight
/// state before letting it finish.
private actor Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func increment() { lock.withLock { value += 1 } }
}

@MainActor
final class ClaudeConnectionControllerTests: XCTestCase {
    private func waitForState(
        _ expected: ClaudeConnectionState,
        in controller: ClaudeConnectionController
    ) async {
        for _ in 0..<200 where controller.state != expected {
            await Task.yield()
        }
        XCTAssertEqual(controller.state, expected)
    }

    func testSignInWithBrowserReachesConnected() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: "pro") },
            credentialsSignIn: { throw ClaudeCredentialError.notFound }
        )

        controller.signInWithBrowser()
        XCTAssertEqual(controller.state, .signingIn(.browser), "in-flight state is applied synchronously")

        await waitForState(.connected(ClaudeAccountSummary(planType: "pro")), in: controller)
    }

    func testUseClaudeCodeCredentialsReachesConnected() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { throw ClaudeSetupTokenError.missingCLI },
            credentialsSignIn: { ClaudeAccountSummary(planType: "max") }
        )

        controller.useClaudeCodeCredentials()
        XCTAssertEqual(controller.state, .signingIn(.claudeCodeCredentials))

        await waitForState(.connected(ClaudeAccountSummary(planType: "max")), in: controller)
    }

    func testMissingCLIMapsToMissingCLIState() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { throw ClaudeSetupTokenError.missingCLI },
            credentialsSignIn: { ClaudeAccountSummary(planType: nil) }
        )

        controller.signInWithBrowser()

        await waitForState(.missingCLI, in: controller)
    }

    func testRejectedSetupTokenMapsToSetupTokenFailure() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { throw ClaudeSetupTokenError.rejected },
            credentialsSignIn: { ClaudeAccountSummary(planType: nil) }
        )

        controller.signInWithBrowser()

        await waitForState(.failed(.setupTokenFailed), in: controller)
    }

    func testKeychainDenialMapsToKeychainFailure() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: nil) },
            credentialsSignIn: { throw ClaudeCredentialError.accessDenied }
        )

        controller.useClaudeCodeCredentials()

        await waitForState(.failed(.keychainAccessDenied), in: controller)
    }

    func testMissingClaudeCodeCredentialsMapsToCredentialsNotFound() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: nil) },
            credentialsSignIn: { throw ClaudeCredentialError.notFound }
        )

        controller.useClaudeCodeCredentials()

        await waitForState(.failed(.credentialsNotFound), in: controller)
    }

    /// The credentials path fetches usage, so it surfaces ClaudeOAuthError,
    /// not just credential-store errors.
    func testOAuthCredentialsNotFoundMapsToCredentialsNotFound() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: nil) },
            credentialsSignIn: { throw ClaudeOAuthError.credentialsNotFound }
        )

        controller.useClaudeCodeCredentials()

        await waitForState(.failed(.credentialsNotFound), in: controller)
    }

    func testOAuthUnauthorizedMapsToCredentialsNotFound() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: nil) },
            credentialsSignIn: { throw ClaudeOAuthError.unauthorized }
        )

        controller.useClaudeCodeCredentials()

        await waitForState(.failed(.credentialsNotFound), in: controller)
    }

    func testOAuthTransportErrorMapsToUsageUnavailable() async {
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: nil) },
            credentialsSignIn: { throw ClaudeOAuthError.transportError }
        )

        controller.useClaudeCodeCredentials()

        await waitForState(.failed(.usageUnavailable), in: controller)
    }

    func testSecondSignInIsIgnoredWhileOneIsInFlight() async {
        let gate = Gate()
        let counter = Counter()
        let controller = ClaudeConnectionController(
            browserSignIn: {
                counter.increment()
                await gate.wait()
                return ClaudeAccountSummary(planType: "pro")
            },
            credentialsSignIn: { throw ClaudeCredentialError.notFound }
        )

        controller.signInWithBrowser()
        await Task.yield()
        controller.signInWithBrowser()
        controller.useClaudeCodeCredentials()
        await Task.yield()

        XCTAssertEqual(counter.count, 1, "a second sign-in must be ignored while one is in flight")
        XCTAssertEqual(controller.state, .signingIn(.browser))

        await gate.open()
        await waitForState(.connected(ClaudeAccountSummary(planType: "pro")), in: controller)
    }

    func testSucceedingMethodIsPersisted() async {
        var persisted: [ClaudeSignInMethod?] = []
        let controller = ClaudeConnectionController(
            browserSignIn: { throw ClaudeSetupTokenError.rejected },
            credentialsSignIn: { ClaudeAccountSummary(planType: "pro") },
            onMethodSelected: { persisted.append($0) }
        )

        controller.useClaudeCodeCredentials()
        await waitForState(.connected(ClaudeAccountSummary(planType: "pro")), in: controller)

        XCTAssertEqual(persisted, [.claudeCodeCredentials])
    }

    func testFailedSignInDoesNotPersistAMethod() async {
        var persisted: [ClaudeSignInMethod?] = []
        let controller = ClaudeConnectionController(
            browserSignIn: { throw ClaudeSetupTokenError.rejected },
            credentialsSignIn: { ClaudeAccountSummary(planType: nil) },
            onMethodSelected: { persisted.append($0) }
        )

        controller.signInWithBrowser()
        await waitForState(.failed(.setupTokenFailed), in: controller)

        XCTAssertTrue(persisted.isEmpty)
    }

    func testSignOutClearsStateAndPersistedMethod() async {
        var persisted: [ClaudeSignInMethod?] = []
        let controller = ClaudeConnectionController(
            browserSignIn: { ClaudeAccountSummary(planType: "pro") },
            credentialsSignIn: { throw ClaudeCredentialError.notFound },
            onMethodSelected: { persisted.append($0) }
        )
        controller.signInWithBrowser()
        await waitForState(.connected(ClaudeAccountSummary(planType: "pro")), in: controller)

        controller.signOut()

        XCTAssertEqual(controller.state, .notConnected)
        XCTAssertEqual(persisted, [.browser, nil], "sign-out clears the persisted method")
    }
}
