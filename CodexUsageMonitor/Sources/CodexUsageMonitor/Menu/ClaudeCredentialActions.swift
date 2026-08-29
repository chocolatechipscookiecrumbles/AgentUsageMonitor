import SwiftUI

/// One disclosed connection action. Claude Code remains the credential owner;
/// this app only asks macOS for read access to its existing Keychain item.
struct ClaudeCredentialActions: View {
    let state: ClaudeConnectionState
    let connect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
            Button(buttonTitle, action: connect)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.accent, in: Capsule())
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.45 : 1)

            Text(ClaudeSignInPresentation.keychainDisclosure)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttonTitle: String {
        if case .failed = state { return "Reconnect Claude" }
        return "Connect Claude"
    }

    private var isDisabled: Bool {
        switch state {
        case .checking, .connecting, .connected: true
        case .notConnected, .failed: false
        }
    }

    private var theme: MenuPopoverTheme { MenuPopoverTheme.resolve(for: colorScheme) }
}
