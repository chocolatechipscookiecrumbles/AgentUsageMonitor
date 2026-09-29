import SwiftUI

struct ClaudeUnavailableContent: View {
    let connectionState: ClaudeConnectionState
    let statusDetail: String?
    let connect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MenuPopoverTheme.compactControlSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: MenuPopoverTheme.unavailableSymbolSize, weight: .medium))
                .foregroundStyle(theme.neutral)
                .frame(width: MenuPopoverTheme.unavailableIconSize, height: MenuPopoverTheme.unavailableIconSize)
                .background(theme.neutral.opacity(0.10), in: Circle())

            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.callout)
                .foregroundStyle(detailTint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: MenuPopoverTheme.unavailableTextWidth)

            if showsConnect {
                ClaudeCredentialActions(state: connectionState, connect: connect)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(color: theme.cardShadow, radius: MenuPopoverTheme.cardShadowRadius, y: MenuPopoverTheme.cardShadowY)
        .accessibilityElement(children: .contain)
    }

    private var showsConnect: Bool {
        switch connectionState {
        case .checking, .connecting: false
        case .notConnected, .failed, .connected: true
        }
    }

    private var title: String { "Monitoring enabled" }

    private var detail: String {
        switch connectionState {
        case .checking, .connecting:
            "Checking live fallback. Waiting for a Claude Code usage capture."
        default:
            (statusDetail ?? "No usage reading is available yet.")
                + " Use Claude Code to capture usage, or open Claude Settings to run /usage."
        }
    }

    private var detailTint: Color {
        if case .failed = connectionState { return theme.warning }
        return theme.secondaryText
    }

    private var theme: MenuPopoverTheme { MenuPopoverTheme.resolve(for: colorScheme) }
}
