import XCTest
@testable import CodexUsageMonitor

private func presentation(_ delivery: ClaudeUsageDelivery, source: ClaudeUsageSource = .oauth) -> ClaudeUsagePresentation {
    ClaudeUsagePresentation(
        snapshot: ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: 44, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: source, capturedAt: .now, schemaVersion: 1
        ),
        delivery: delivery,
        warnings: []
    )
}

final class ClaudeConnectionStatusTests: XCTestCase {
    // MARK: what "connected" means

    /// Connected means we authenticated and got a live read just now — not
    /// merely that some number is on screen.
    func testLiveReadIsConnected() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .notConnected,
            usageState: .available(presentation(.live))
        )
        XCTAssertTrue(status.isConnected)
        XCTAssertEqual(status.text, "Connected")
    }

    /// The rail's old bug: a cached snapshot is data, not a connection. A
    /// 47-hour-old cache reported "Connected".
    func testCachedDataIsNotAConnection() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .notConnected,
            usageState: .available(presentation(.cached))
        )
        XCTAssertFalse(status.isConnected)
        XCTAssertEqual(status.text, "Not connected")
    }

    func testPassiveCaptureIsNotAConnection() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .notConnected,
            usageState: .available(presentation(.passiveSnapshot, source: .statusLine))
        )
        XCTAssertFalse(status.isConnected)
    }

    func testUnavailableIsNotConnected() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .notConnected,
            usageState: .unavailable(reason: "nope")
        )
        XCTAssertFalse(status.isConnected)
    }

    /// The agent page's old bug: a live read was showing "Disconnected"
    /// because nobody had pressed the sign-in button.
    func testLiveReadOutranksAnUnpressedSignInButton() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .notConnected,
            usageState: .available(presentation(.live))
        )
        XCTAssertTrue(status.isConnected, "a working live read is a connection regardless of the button")
    }

    // MARK: sign-in flow still surfaces

    func testSignInInFlightIsReported() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .signingIn(.claudeCodeCredentials),
            usageState: .unavailable(reason: "x")
        )
        XCTAssertFalse(status.isConnected)
        XCTAssertTrue(status.text.contains("Signing in"), status.text)
    }

    /// A failure the user just caused must not be hidden by stale live data.
    func testExplicitFailureOutranksData() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .failed(.keychainAccessDenied),
            usageState: .available(presentation(.cached))
        )
        XCTAssertFalse(status.isConnected)
        XCTAssertEqual(status.text, "Needs attention")
        XCTAssertEqual(status.detail, ClaudeConnectionFailure.keychainAccessDenied.displayMessage)
    }

    /// But a live read proves the credential works, so it supersedes an older
    /// failure rather than leaving the page contradicting itself.
    func testLiveReadClearsAStaleFailure() {
        let status = ClaudeConnectionStatus.resolve(
            signInState: .failed(.keychainAccessDenied),
            usageState: .available(presentation(.live))
        )
        XCTAssertTrue(status.isConnected)
    }

    /// The rail and the agent page must never disagree again.
    func testRailAndPageDeriveFromTheSameSource() {
        let usage = ClaudeUsageState.available(presentation(.live))
        let status = ClaudeConnectionStatus.resolve(signInState: .notConnected, usageState: usage)
        let summary = ProviderContextSummary.claude(
            connectionState: .notConnected, usageState: usage, now: .now
        )
        XCTAssertEqual(summary.isConnected, status.isConnected)
        XCTAssertEqual(summary.statusText, status.text)
    }
}
