import XCTest
@testable import CodexUsageMonitor

final class ClaudeConnectionStateTests: XCTestCase {
    func testSignInMethodDisplayNames() {
        XCTAssertEqual(ClaudeSignInMethod.browser.displayName, "browser")
        XCTAssertEqual(ClaudeSignInMethod.claudeCodeCredentials.displayName, "Claude Code credentials")
    }

    func testIsConnectedOnlyForConnectedState() {
        XCTAssertTrue(ClaudeConnectionState.connected(ClaudeAccountSummary(planType: "pro")).isConnected)
        XCTAssertFalse(ClaudeConnectionState.checking.isConnected)
        XCTAssertFalse(ClaudeConnectionState.notConnected.isConnected)
        XCTAssertFalse(ClaudeConnectionState.signingIn(.browser).isConnected)
        XCTAssertFalse(ClaudeConnectionState.failed(.setupTokenFailed).isConnected)
        XCTAssertFalse(ClaudeConnectionState.missingCLI.isConnected)
    }

    func testStateDisplayNameNamesTheSigningInMethod() {
        XCTAssertEqual(ClaudeConnectionState.signingIn(.browser).displayName, "Signing in with browser")
        XCTAssertEqual(
            ClaudeConnectionState.signingIn(.claudeCodeCredentials).displayName,
            "Signing in with Claude Code credentials"
        )
    }

    /// Mirrors AgentConnectionFailure's copy convention: a failure in one
    /// method points the user at the other method as the recovery path.
    func testBrowserFailuresPointAtClaudeCodeCredentials() {
        let browserFailures: [ClaudeConnectionFailure] = [
            .browserCouldNotOpen, .setupTokenFailed, .setupTokenTimedOut, .missingClaudeCLI,
        ]
        for failure in browserFailures {
            XCTAssertTrue(
                failure.displayMessage.contains("Claude Code credentials"),
                "\(failure) should name the Claude Code credentials method as recovery"
            )
        }
    }

    func testKeychainFailuresPointAtBrowserSignIn() {
        let keychainFailures: [ClaudeConnectionFailure] = [.keychainAccessDenied, .credentialsNotFound]
        for failure in keychainFailures {
            XCTAssertTrue(
                failure.displayMessage.contains("browser"),
                "\(failure) should name browser sign-in as recovery"
            )
        }
    }

    func testNoFailureMessageIsEmpty() {
        let all: [ClaudeConnectionFailure] = [
            .browserCouldNotOpen, .setupTokenFailed, .setupTokenTimedOut, .missingClaudeCLI,
            .keychainAccessDenied, .credentialsNotFound, .usageUnavailable,
        ]
        for failure in all {
            XCTAssertFalse(failure.displayMessage.isEmpty, "\(failure) needs user-facing copy")
        }
    }
}
