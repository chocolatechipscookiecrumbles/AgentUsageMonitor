import SwiftUI

/// Shown alongside the last result when Claude's connection has actively
/// failed, so the credential affordance stays reachable without discarding
/// the data already on screen. Not shown for a merely-not-connected account,
/// because passive capture needs no connection.
struct ClaudeConnectionRecoveryCard: View {
    let state: ClaudeConnectionState
    let connectWithCredentials: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlSpacing) {
            Text("Claude connection needs attention")
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.caption)
                .foregroundStyle(theme.warning)
                .lineLimit(MenuPopoverTheme.maximumDetailLines)
                .fixedSize(horizontal: false, vertical: true)

            ClaudeCredentialActions(
                state: state,
                connectWithCredentials: connectWithCredentials
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
        if case .failed(let failure) = state {
            return failure.displayMessage
        }
        return "Reconnect Claude Code credentials to restore live updates."
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
