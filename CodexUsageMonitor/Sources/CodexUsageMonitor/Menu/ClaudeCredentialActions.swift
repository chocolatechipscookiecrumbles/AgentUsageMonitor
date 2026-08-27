import SwiftUI

/// Setup-token is the durable primary route. Borrowing Claude Code's Keychain
/// item remains an explicit compatibility action and never runs as fallback.
struct ClaudeCredentialActions: View {
    let state: ClaudeConnectionState
    let connectWithSetupToken: () -> Void
    let connectWithCredentials: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
            if ClaudeSetupTokenAvailability.isEnabled {
                Button(primaryButtonTitle, action: connectWithSetupToken)
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                    .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                    .background(theme.accent, in: Capsule())
                    .disabled(isDisabled || state == .missingCLI)
                    .opacity(isDisabled || state == .missingCLI ? 0.45 : 1)

                Text("Claude Code opens sign-in and creates a long-lived token stored in this app’s Keychain item.")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Use Claude Code credentials…", action: connectWithCredentials)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.secondaryText.opacity(0.22), in: Capsule())
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

    private var primaryButtonTitle: String {
        if case .failed = state { return "Reconnect Claude" }
        return "Connect with Claude"
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
