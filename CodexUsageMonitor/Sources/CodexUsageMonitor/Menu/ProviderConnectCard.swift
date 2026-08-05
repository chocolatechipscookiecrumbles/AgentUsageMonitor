import SwiftUI

/// The one card an unenrolled provider tab shows.
///
/// It is deliberately not a variant of `CodexUnavailableContent` or
/// `ClaudeUnavailableContent`: those render a *connection* state, and reaching
/// them requires having asked the provider something. Before enrollment the app
/// has asked nothing, so there is one state to draw and no state machine behind
/// it. Both providers share this view so the two tabs cannot drift apart.
struct ProviderConnectCard: View {
    let provider: AgentProvider
    let connect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MenuPopoverTheme.compactControlSpacing) {
            Image(systemName: provider.systemImage)
                .font(.system(size: MenuPopoverTheme.unavailableSymbolSize, weight: .medium))
                .foregroundStyle(theme.neutral)
                .frame(
                    width: MenuPopoverTheme.unavailableIconSize,
                    height: MenuPopoverTheme.unavailableIconSize
                )
                .background(theme.neutral.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: MenuPopoverTheme.unavailableTextWidth)

            Button(title, action: connect)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.accent, in: Capsule())
                .accessibilityLabel(title)
                .accessibilityHint(detail)
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

    private var title: String {
        "Connect \(provider.tabTitle)"
    }

    /// Claude's copy names the Keychain because its connection can raise a
    /// system prompt, and a prompt the user was not warned about is the exact
    /// thing the 0.0.1 setup reports complained of.
    private var detail: String {
        switch provider {
        case .codex:
            "Connect Codex to show quota and local activity from this Mac."
        case .claudeCode:
            "Connect through Claude Code to show quota and local activity. The connection may ask for Keychain access."
        case .githubCopilot:
            "Connect \(provider.title) to show usage from this Mac."
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
