import SwiftUI

/// Replaces the quota card while credential access needs attention, keeping
/// the non-scrolling menu within the display height.
struct ClaudeConnectionRecoveryCard: View {
    let state: ClaudeConnectionState
    let connect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlSpacing) {
            Text(state == .connecting ? "Connecting Claude…" : "Claude connection needs attention")
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.callout)
                .foregroundStyle(theme.warning)
                .fixedSize(horizontal: false, vertical: true)

            ClaudeCredentialActions(state: state, connect: connect)
        }
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(color: theme.cardShadow, radius: MenuPopoverTheme.cardShadowRadius, y: MenuPopoverTheme.cardShadowY)
    }

    private var detail: String {
        if state == .connecting {
            return ClaudeConnectionCopy.keychainPromptExplanation
        }
        if case .failed(let failure) = state { return failure.displayMessage }
        return "Reconnect to restore live updates. Passive capture remains available after Claude Code’s next turn."
    }

    private var theme: MenuPopoverTheme { MenuPopoverTheme.resolve(for: colorScheme) }
}
