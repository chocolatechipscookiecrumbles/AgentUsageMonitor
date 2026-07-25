import SwiftUI

/// Standardized Disconnect control shared by every agent page.
///
/// The visual and interaction contract — label, destructive role, confirmation,
/// and the reassurance that the provider's own session is untouched — is
/// identical across providers. Only the injected action and the provider name
/// differ, because each provider connects differently (Codex via a CLI session,
/// Claude via the Keychain credential).
struct AgentDisconnectButton: View {
    let provider: AgentProvider
    let disconnect: () -> Void

    @State private var isConfirming = false

    var body: some View {
        Button("Disconnect", role: .destructive) {
            isConfirming = true
        }
        .confirmationDialog(
            "Disconnect \(provider.tabTitle)?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive, action: disconnect)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.reassurance(for: provider))
        }
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
