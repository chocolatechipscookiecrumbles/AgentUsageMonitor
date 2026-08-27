import Foundation

/// The two explicit Claude credential methods. Neither is a silent fallback
/// of the other: the user picks, so any cross-app Keychain grant is informed.
enum ClaudeSignInMethod: String, Equatable, Sendable, Codable {
    /// `claude setup-token` — the CLI runs the browser OAuth flow and emits a
    /// long-lived token we store in our own Keychain item.
    case setupToken
    /// Read Claude Code's existing Keychain credential (`Claude Code-credentials`).
    case claudeCodeCredentials

    var displayName: String {
        switch self {
        case .setupToken: "setup token"
        case .claudeCodeCredentials: "Claude Code credentials"
        }
    }
}

struct ClaudeAccountSummary: Equatable, Sendable {
    let planType: String?
}

/// Failure copy follows AgentConnectionFailure's convention: a failure in one
/// method names the *other* method as the recovery path, so the user always
/// has a next step.
enum ClaudeConnectionFailure: Equatable, Sendable {
    case browserCouldNotOpen
    case setupTokenFailed
    case setupTokenTimedOut
    case missingClaudeCLI
    case keychainAccessDenied
    case keychainStorageFailed
    case credentialsNotFound
    case usageUnavailable

    var displayMessage: String {
        switch self {
        case .browserCouldNotOpen:
            "The sign-in page could not be opened. Try setup-token sign-in again, or use Claude Code credentials instead."
        case .setupTokenFailed:
            "Claude did not complete setup-token sign-in. Try again, or use Claude Code credentials instead."
        case .setupTokenTimedOut:
            "Setup-token sign-in took too long. Start it again when you’re ready, or use Claude Code credentials instead."
        case .missingClaudeCLI:
            "The Claude CLI could not be found, so setup-token sign-in is unavailable. Install it, or use Claude Code credentials instead."
        case .keychainAccessDenied:
            "Keychain access to Claude Code’s credentials was denied. Allow it in Keychain Access, or use a setup token instead."
        case .keychainStorageFailed:
            "The setup token could not be stored or removed from this app’s Keychain item. Check Keychain access and try again."
        case .credentialsNotFound:
            "No Claude Code credentials were found. Sign in to Claude Code first, or use a setup token instead."
        case .usageUnavailable:
            "Claude accepted the credential but returned no usage. Try again shortly."
        }
    }
}

enum ClaudeConnectionState: Equatable, Sendable {
    case checking
    case missingCLI
    case notConnected
    case signingIn(ClaudeSignInMethod)
    case connected(ClaudeAccountSummary)
    case failed(ClaudeConnectionFailure)

    /// The plan a live connection proves, as Anthropic spells it. Only a
    /// connected state has one; a usage snapshot's plan hint is a separate,
    /// weaker claim and stays with that snapshot.
    var accountPlanType: String? {
        if case .connected(let account) = self { return account.planType }
        return nil
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .checking: "Checking connection"
        case .missingCLI: "Claude CLI not found"
        case .notConnected: "Not connected"
        case .signingIn(let method): "Signing in with \(method.displayName)"
        case .connected: "Connected"
        case .failed: "Connection needs attention"
        }
    }
}
