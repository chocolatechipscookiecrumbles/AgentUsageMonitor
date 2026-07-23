import SwiftUI

struct CodexUnavailableContent: View {
    let state: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MenuPopoverTheme.compactControlSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: MenuPopoverTheme.unavailableSymbolSize, weight: .medium))
                .foregroundStyle(theme.neutral)
                .frame(
                    width: MenuPopoverTheme.unavailableIconSize,
                    height: MenuPopoverTheme.unavailableIconSize
                )
                .background(theme.neutral.opacity(0.10), in: Circle())

            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.caption)
                .foregroundStyle(detailTint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: MenuPopoverTheme.unavailableTextWidth)

            if showsSignInActions {
                CodexSignInActions(
                    state: state,
                    signInWithBrowser: signInWithBrowser,
                    signInWithCLI: signInWithCLI
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
        .accessibilityElement(children: .contain)
    }

    /// Sign-in controls only make sense when the account is absent. While
    /// checking there is nothing to offer yet, and when already connected the
    /// account exists — the missing piece is a quota result, which the footer's
    /// Refresh Now covers — so disabled sign-in buttons would only mislead.
    private var showsSignInActions: Bool {
        switch state {
        case .checking, .connected:
            false
        case .missingCLI, .disconnected, .signingIn, .failed:
            true
        }
    }

    private var title: String {
        switch state {
        case .checking:
            "Checking Codex connection…"
        case .missingCLI:
            "Codex CLI not found"
        case .disconnected:
            "Codex isn’t connected"
        case .signingIn(let method):
            "Signing in with \(method.displayName)…"
        case .failed:
            "Codex connection needs attention"
        case .connected:
            "Unable to Read Usage"
        }
    }

    private var detail: String {
        switch state {
        case .checking:
            "Checking for a Codex account before reading usage."
        case .missingCLI:
            "Install the Codex CLI, then reopen the app to connect your account."
        case .disconnected:
            "Sign in to show current five-hour and weekly usage."
        case .signingIn(.browser):
            "Finish signing in in your browser."
        case .signingIn(.cli):
            "Finish signing in in the Terminal window."
        case .failed(let failure):
            failure.displayMessage
        case .connected:
            "No confirmed Codex quota result is available yet. Use Refresh Now below to try again."
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
