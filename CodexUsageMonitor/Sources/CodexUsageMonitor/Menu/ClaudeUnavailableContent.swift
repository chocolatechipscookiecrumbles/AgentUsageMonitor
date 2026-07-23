import SwiftUI

/// The explicit Claude unavailable/setup card, shown when no snapshot is
/// available. It states why there is no number and, when the account is
/// absent or broken, offers the credential affordance. When Claude is
/// connected but has not returned usage yet, it points at the footer's
/// Refresh Now rather than a sign-in that would not help.
struct ClaudeUnavailableContent: View {
    let connectionState: ClaudeConnectionState
    let connectWithCredentials: () -> Void

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
                .lineLimit(MenuPopoverTheme.maximumDetailLines)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: MenuPopoverTheme.unavailableTextWidth)

            if showsCredentialAction {
                ClaudeCredentialActions(
                    state: connectionState,
                    connectWithCredentials: connectWithCredentials
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

    /// The credential path helps only when the account is absent or broken.
    /// While checking or signing in there is nothing to offer yet, and when
    /// already connected the missing piece is a usage result — the footer's
    /// Refresh Now covers that.
    private var showsCredentialAction: Bool {
        switch connectionState {
        case .checking, .signingIn, .connected:
            false
        case .missingCLI, .notConnected, .failed:
            true
        }
    }

    private var title: String {
        switch connectionState {
        case .checking:
            "Checking Claude connection…"
        case .missingCLI:
            "Claude CLI not found"
        case .notConnected:
            "Claude isn’t connected"
        case .signingIn(let method):
            "Signing in with \(method.displayName)…"
        case .failed:
            "Claude connection needs attention"
        case .connected:
            "Unable to read usage"
        }
    }

    private var detail: String {
        switch connectionState {
        case .checking:
            "Checking for Claude credentials before reading usage."
        case .missingCLI:
            "Install the Claude CLI, or connect the credentials Claude Code already stored."
        case .notConnected:
            "Connect to show current five-hour and weekly usage."
        case .signingIn(.browser):
            "Finish signing in in your browser."
        case .signingIn(.claudeCodeCredentials):
            "Approve the Keychain prompt to continue."
        case .failed(let failure):
            failure.displayMessage
        case .connected:
            "No confirmed Claude usage result is available yet. Use Refresh Now below to try again."
        }
    }

    private var detailTint: Color {
        if case .failed = connectionState {
            return theme.warning
        }
        return theme.secondaryText
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
