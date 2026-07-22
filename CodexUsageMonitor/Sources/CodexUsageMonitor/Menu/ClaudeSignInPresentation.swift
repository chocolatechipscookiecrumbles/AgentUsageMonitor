import Foundation

/// Pure copy/state mapping for the Claude sign-in surface, so the two-method
/// wording is unit-tested rather than buried in a view body (matching the
/// MenuBarLabelPresentation / SettingsStatus convention).
struct ClaudeSignInPresentation: Equatable {
    let title: String
    let detail: String?
    let signInDisabled: Bool
    let showsSignOut: Bool

    /// Shown next to the Claude Code credentials button. The user must know
    /// what that method grants *before* macOS raises the Keychain dialog.
    static let keychainDisclosure =
        "Reads the OAuth token Claude Code already stored in your Keychain. macOS will ask for permission."

    static func make(
        state: ClaudeConnectionState,
        activeMethod: ClaudeSignInMethod? = nil
    ) -> ClaudeSignInPresentation {
        ClaudeSignInPresentation(
            title: title(for: state),
            detail: detail(for: state, activeMethod: activeMethod),
            signInDisabled: signInDisabled(for: state),
            showsSignOut: state.isConnected
        )
    }

    private static func title(for state: ClaudeConnectionState) -> String {
        switch state {
        case .checking: "Checking Claude connection…"
        case .missingCLI: "Claude CLI not found"
        case .notConnected: "Claude isn’t connected"
        case .signingIn(let method): "Signing in with \(method.displayName)…"
        case .connected: "Claude connected"
        case .failed: "Claude connection needs attention"
        }
    }

    private static func detail(
        for state: ClaudeConnectionState,
        activeMethod: ClaudeSignInMethod?
    ) -> String? {
        switch state {
        case .checking:
            nil
        case .missingCLI:
            "Install the Claude CLI to sign in with a browser, or use Claude Code credentials instead."
        case .notConnected:
            "Sign in to show current five-hour and weekly usage."
        case .signingIn(.browser):
            "Finish signing in in your browser."
        case .signingIn(.claudeCodeCredentials):
            "Approve the Keychain prompt to continue."
        case .connected(let account):
            connectedDetail(account: account, activeMethod: activeMethod)
        case .failed(let failure):
            failure.displayMessage
        }
    }

    private static func connectedDetail(
        account: ClaudeAccountSummary,
        activeMethod: ClaudeSignInMethod?
    ) -> String? {
        let via = activeMethod.map { "via \($0.displayName)" }
        guard let plan = account.planType else { return via }
        guard let via else { return "Plan: \(plan)" }
        return "Plan: \(plan) · \(via)"
    }

    /// Only an in-flight sign-in or an established connection disables the
    /// buttons — a failure must remain retryable, and a missing CLI must
    /// still leave the Claude Code credentials method reachable.
    private static func signInDisabled(for state: ClaudeConnectionState) -> Bool {
        switch state {
        case .signingIn, .checking, .connected: true
        case .notConnected, .failed, .missingCLI: false
        }
    }
}
