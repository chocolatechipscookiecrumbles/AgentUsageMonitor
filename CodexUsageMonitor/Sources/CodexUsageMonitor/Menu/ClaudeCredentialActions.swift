import SwiftUI

/// One disclosed connection action. Claude Code remains the credential owner;
/// this app only asks macOS for read access to its existing Keychain item.
struct ClaudeCredentialActions: View {
    let state: ClaudeConnectionState
    let connect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
            Text(ClaudeConnectionCopy.keychainDisclosure)
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(buttonTitle, action: connect)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MenuPopoverTheme.compactButtonHorizontalPadding)
                .padding(.vertical, MenuPopoverTheme.compactButtonVerticalPadding)
                .background(theme.accent, in: Capsule())
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.45 : 1)
        }
    }

    private var buttonTitle: String { "Reconnect Claude" }

    private var isDisabled: Bool {
        switch state {
        case .checking, .connecting: true
        case .notConnected, .failed, .connected: false
        }
    }

    private var theme: MenuPopoverTheme { MenuPopoverTheme.resolve(for: colorScheme) }
}
