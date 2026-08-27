import SwiftUI

/// Standardized Disconnect control shared by every agent page.
///
/// The visual and interaction contract — immediate action, destructive role,
/// and reassurance that the provider's own session is untouched — is identical
/// across providers. Only the injected action and provider name differ.
struct AgentDisconnectButton: View {
    let provider: AgentProvider
    let disconnect: () -> Void

    var body: some View {
        Button("Disconnect", role: .destructive, action: disconnect)
            .help(Self.reassurance(for: provider))
    }

    /// The disconnect is app-local, so the copy emphasizes that the provider's
    /// own login/credential is not changed — the common worry.
    private static func reassurance(for provider: AgentProvider) -> String {
        switch provider {
        case .codex:
            "This hides Codex usage in the app. Your Codex CLI login is not signed out."
        case .claudeCode:
            "This stops reading Claude usage in the app. Your Claude Code credentials are not changed."
        case .githubCopilot:
            "This disconnects the agent in the app."
        }
    }
}
