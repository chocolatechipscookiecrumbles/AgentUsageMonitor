import SwiftUI

struct MenuActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    init(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MenuPopoverTheme.actionRowSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: MenuPopoverTheme.actionRowIconSize))
                    .frame(width: MenuPopoverTheme.actionRowIconWidth)
                    .foregroundStyle(theme.icon.opacity(isEnabled ? 1 : 0.4))

                Text(title)
                    .font(.callout)
                    .foregroundStyle(theme.primaryText.opacity(isEnabled ? 1 : 0.4))

                Spacer(minLength: 0)
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
