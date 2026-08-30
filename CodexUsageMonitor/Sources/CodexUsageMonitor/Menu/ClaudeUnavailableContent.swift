import SwiftUI

struct ClaudeUnavailableContent: View {
    let connectionState: ClaudeConnectionState
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
        case .checking, .connecting, .connected: false
        case .notConnected, .failed: true
        }
    }

    private var title: String {
        switch connectionState {
        case .checking: "Checking Claude connection…"
        case .connecting: "Connecting Claude…"
        case .notConnected: "Claude isn’t connected"
        case .failed: "Claude connection needs attention"
        case .connected: "Unable to read usage"
        }
    }

    private var detail: String {
        switch connectionState {
        case .checking: "Checking for Claude credentials before reading usage."
        case .connecting: "Approve the Keychain prompt and choose Always Allow for background updates."
        case .notConnected: "Connect once to show live usage and enable passive capture."
        case .failed(let failure): failure.displayMessage
        case .connected: "No confirmed Claude usage result is available yet. Use Refresh Now to try again."
        }
    }

    private var detailTint: Color {
        if case .failed = connectionState { return theme.warning }
        return theme.secondaryText
    }

    private var theme: MenuPopoverTheme { MenuPopoverTheme.resolve(for: colorScheme) }
}
