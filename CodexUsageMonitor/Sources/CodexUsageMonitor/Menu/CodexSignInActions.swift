import SwiftUI

struct CodexSignInActions: View {
    let state: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MenuPopoverTheme.compactControlSpacing) {
            Button("Sign in with browser", action: signInWithBrowser)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.accent, in: Capsule())
                .disabled(signInDisabled)

            Button("Sign in with Codex CLI…", action: signInWithCLI)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.hoverBackground, in: Capsule())
                .disabled(signInDisabled)
        }
        .opacity(signInDisabled ? 0.45 : 1)
    }

    private var signInDisabled: Bool {
        switch state {
        case .missingCLI, .signingIn, .checking, .connected:
            true
        case .disconnected, .failed:
            false
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
