import SwiftUI

struct CodexConnectionRecoveryCard: View {
    let state: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlSpacing) {
            Text("Codex connection needs attention")
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.caption)
                .foregroundStyle(detailTint)
                .lineLimit(MenuPopoverTheme.maximumDetailLines)
                .fixedSize(horizontal: false, vertical: true)

            CodexSignInActions(
                state: state,
                signInWithBrowser: signInWithBrowser,
                signInWithCLI: signInWithCLI
            )
        }
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
    }

    private var detail: String {
        switch state {
        case .checking:
            "Checking Codex connection."
        case .missingCLI:
            "Install the Codex CLI, then reopen the app to reconnect."
        case .disconnected:
            "Sign in again to restore live updates."
        case .signingIn(let method):
            "Finish signing in with \(method.displayName)."
        case .failed(let failure):
            failure.displayMessage
        case .connected:
            "Codex is connected."
        }
    }

    private var detailTint: Color {
        if case .failed = state {
            return theme.warning
        }
        return theme.secondaryText
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
