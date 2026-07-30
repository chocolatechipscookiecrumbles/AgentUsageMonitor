import SwiftUI

struct MenuActionRow: View {
    let title: String
    let systemImage: String
    /// Present only while the user has keyboard shortcuts enabled. `nil` both
    /// hides the trailing symbol and leaves the key equivalent unregistered,
    /// so the preference cannot leave a live but invisible shortcut behind.
    let shortcut: MenuActionShortcut?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    init(
        _ title: String,
        systemImage: String,
        shortcut: MenuActionShortcut? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        if let shortcut {
            button.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: MenuPopoverTheme.actionRowSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: MenuPopoverTheme.actionRowIconSize))
                    .frame(width: MenuPopoverTheme.actionRowIconWidth)
                    .foregroundStyle(theme.icon.opacity(isEnabled ? 1 : 0.4))

                Text(title)
                    .font(.callout)
                    .foregroundStyle(theme.primaryText.opacity(isEnabled ? 1 : 0.4))

                Spacer(minLength: MenuPopoverTheme.actionRowSpacing)

                if let shortcut {
                    Text(shortcut.displayString)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText.opacity(isEnabled ? 1 : 0.4))
                }
            }
            .padding(.horizontal, MenuPopoverTheme.actionRowHorizontalPadding)
            .frame(height: MenuPopoverTheme.actionRowHeight)
            .contentShape(.rect)
            .background(isHovering && isEnabled ? theme.hoverBackground : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
