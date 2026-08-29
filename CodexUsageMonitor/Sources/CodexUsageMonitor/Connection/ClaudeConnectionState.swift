import Foundation

struct ClaudeAccountSummary: Equatable, Sendable {
    let planType: String?
}

enum ClaudeConnectionFailure: Equatable, Sendable {
    case keychainAccessDenied
    case credentialsNotFound
    case usageUnavailable

    var displayMessage: String {
        switch self {
        case .keychainAccessDenied:
            "macOS denied access to Claude Code’s credential. Reconnect and choose Always Allow in the Keychain prompt."
        case .credentialsNotFound:
            "No Claude Code credential was found. Sign in to Claude Code, then reconnect here."
        case .usageUnavailable:
            "Claude accepted the credential but returned no usage. Try again shortly."
        }
    }
}

enum ClaudeConnectionState: Equatable, Sendable {
    case checking
    case notConnected
    case connecting
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
        case .notConnected: "Not connected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Connection needs attention"
        }
    }
}
