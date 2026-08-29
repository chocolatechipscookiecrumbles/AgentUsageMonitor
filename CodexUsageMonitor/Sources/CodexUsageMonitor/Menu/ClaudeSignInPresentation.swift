import Foundation

struct ClaudeSignInPresentation: Equatable {
    let title: String
    let detail: String?
    let signInDisabled: Bool
    let showsSignOut: Bool

    static let keychainDisclosure =
        "Reads the OAuth credential Claude Code already stores in your Keychain. macOS asks for permission once."

    static let keychainPromptExplanation = """
        macOS asks because Agent Monitor and Claude Code are different applications.

        Choose Always Allow so scheduled refreshes can read usage without interrupting you. Agent Monitor never changes or deletes Claude Code’s credential.
        """

    static func make(state: ClaudeConnectionState) -> ClaudeSignInPresentation {
        ClaudeSignInPresentation(
            title: title(for: state),
            detail: detail(for: state),
            signInDisabled: state == .checking || state == .connecting || state.isConnected,
            showsSignOut: state.isConnected
        )
    }

    private static func title(for state: ClaudeConnectionState) -> String {
        switch state {
        case .checking: "Checking Claude connection…"
        case .notConnected: "Claude isn’t connected"
        case .connecting: "Connecting Claude…"
        case .connected: "Claude connected"
        case .failed: "Claude connection needs attention"
        }
    }

    private static func detail(for state: ClaudeConnectionState) -> String? {
        switch state {
        case .checking: nil
        case .notConnected: "Connect once to show current five-hour and weekly usage."
        case .connecting: "Approve the Keychain prompt and choose Always Allow."
        case .connected(let account):
            account.planType.map { "Plan: \($0)" }
        case .failed(let failure): failure.displayMessage
        }
    }
}
