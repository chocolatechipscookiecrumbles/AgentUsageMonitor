import XCTest
@testable import CodexUsageMonitor

final class ClaudeSignInPresentationTests: XCTestCase {
    func testNotConnectedInvitesEitherMethod() {
        let presentation = ClaudeSignInPresentation.make(state: .notConnected)

        XCTAssertEqual(presentation.title, "Claude isn’t connected")
        XCTAssertFalse(presentation.signInDisabled)
        XCTAssertFalse(presentation.showsSignOut)
    }

    func testSigningInNamesTheMethodAndDisablesButtons() {
        let presentation = ClaudeSignInPresentation.make(state: .signingIn(.browser))

        XCTAssertEqual(presentation.title, "Signing in with browser…")
        XCTAssertTrue(presentation.signInDisabled)
    }

    func testConnectedShowsPlanAndActiveMethod() {
        let presentation = ClaudeSignInPresentation.make(
            state: .connected(ClaudeAccountSummary(planType: "pro")),
            activeMethod: .browser
        )

        XCTAssertEqual(presentation.title, "Claude connected")
        XCTAssertEqual(presentation.detail, "Plan: pro · via browser")
        XCTAssertTrue(presentation.showsSignOut)
        XCTAssertTrue(presentation.signInDisabled)
    }

    func testConnectedWithoutPlanStillNamesTheMethod() {
        let presentation = ClaudeSignInPresentation.make(
            state: .connected(ClaudeAccountSummary(planType: nil)),
            activeMethod: .claudeCodeCredentials
        )

        XCTAssertEqual(presentation.detail, "via Claude Code credentials")
    }

    func testFailureSurfacesTheFailureCopy() {
        let presentation = ClaudeSignInPresentation.make(state: .failed(.keychainAccessDenied))

        XCTAssertEqual(presentation.title, "Claude connection needs attention")
        XCTAssertEqual(presentation.detail, ClaudeConnectionFailure.keychainAccessDenied.displayMessage)
        XCTAssertFalse(presentation.signInDisabled, "the user must be able to retry after a failure")
    }

    func testMissingCLIStillAllowsTheKeychainMethod() {
        let presentation = ClaudeSignInPresentation.make(state: .missingCLI)

        XCTAssertEqual(presentation.title, "Claude CLI not found")
        XCTAssertFalse(
            presentation.signInDisabled,
            "browser sign-in needs the CLI, but Claude Code credentials must stay available"
        )
    }

    /// Gate criterion: the Keychain method must always say what it grants
    /// before the user triggers the ACL prompt.
    func testKeychainDisclosureIsAlwaysPresent() {
        XCTAssertTrue(
            ClaudeSignInPresentation.keychainDisclosure.contains("Claude Code"),
            "disclosure must name whose credentials are being read"
        )
        XCTAssertFalse(ClaudeSignInPresentation.keychainDisclosure.isEmpty)
    }
}

extension ClaudeSignInPresentationTests {
    /// The prompt recurs unless the user picks Always Allow, so the copy has
    /// to name both options and say what each costs.
    func testKeychainExplanationCoversBothPromptChoices() {
        let copy = ClaudeSignInPresentation.keychainPromptExplanation
        XCTAssertTrue(copy.contains("Always Allow"), copy)
        XCTAssertTrue(copy.contains("Allow"), copy)
        XCTAssertTrue(copy.lowercased().contains("background"), "must say background refreshes never prompt")
    }
}
