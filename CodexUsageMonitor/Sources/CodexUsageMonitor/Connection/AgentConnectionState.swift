import Foundation

enum AgentSignInMethod: Equatable, Sendable {
    case browser
    case cli

    var displayName: String {
        switch self {
        case .browser: "browser"
        case .cli: "Codex CLI"
        }
    }
}

struct AgentAccountSummary: Equatable, Sendable {
    let planType: String?
}

enum AgentConnectionFailure: Equatable, Sendable {
    case appServerUnavailable
    case browserCouldNotOpen
    case signInFailed
    case signInTimedOut
    case cliCouldNotOpen
    case cliSignInTimedOut

    var displayMessage: String {
        switch self {
        case .appServerUnavailable:
            "Codex could not check the account. Try again, or use the Codex CLI sign-in option."
        case .browserCouldNotOpen:
            "The sign-in page could not be opened. Try browser sign-in again."
        case .signInFailed:
            "Codex did not complete sign-in. Try either sign-in option again."
        case .signInTimedOut:
            "Browser sign-in took too long. Start it again when you’re ready."
        case .cliCouldNotOpen:
            "Terminal could not be opened. Try the browser sign-in option instead."
        case .cliSignInTimedOut:
            "Codex CLI sign-in was not confirmed. Finish signing in, then try again."
        }
    }
}

enum AgentConnectionState: Equatable, Sendable {
    case checking
    case missingCLI
    case disconnected
    case signingIn(AgentSignInMethod)
    case connected(AgentAccountSummary)
    case failed(AgentConnectionFailure)

    /// The plan a live connection proves, as the provider spells it. Only a
    /// connected state has one — a cached quota record's plan is a separate,
    /// weaker claim and stays with that record.
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
        case .missingCLI: "Codex CLI not found"
        case .disconnected: "Not connected"
        case .signingIn(let method): "Signing in with \(method.displayName)"
        case .connected: "Connected"
        case .failed: "Connection needs attention"
        }
    }
}
