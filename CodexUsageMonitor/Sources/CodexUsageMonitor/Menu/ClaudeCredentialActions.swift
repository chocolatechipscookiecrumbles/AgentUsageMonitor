import SwiftUI

/// The single user-initiated Claude credential affordance. Browser sign-in is
/// shelved as unverified, so — unlike Codex's two-button pair — only the
/// Claude Code credentials method is offered, with its Keychain disclosure
/// stated before macOS raises the prompt.
struct ClaudeCredentialActions: View {
    let state: ClaudeConnectionState
    let connectWithCredentials: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
            Button("Use Claude Code credentials…", action: connectWithCredentials)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.accent, in: Capsule())
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.45 : 1)

            Text(ClaudeSignInPresentation.keychainDisclosure)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Mirrors `ClaudeSignInPresentation.signInDisabled`: an in-flight sign-in
    /// or an established connection disables it, while a failure stays
    /// retryable and a missing CLI still leaves the credential path reachable
    /// because it reads the Keychain, not the CLI.
    private var isDisabled: Bool {
        switch state {
        case .signingIn, .checking, .connected:
            true
        case .notConnected, .failed, .missingCLI:
            false
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
