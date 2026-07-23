import SwiftUI

struct MenuPopoverChrome<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .frame(width: MenuPopoverTheme.popoverWidth)
            .background(theme.windowBackground)
            .clipShape(.rect(cornerRadius: MenuPopoverTheme.shellCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
                    .stroke(theme.border, lineWidth: MenuPopoverTheme.shellBorderWidth)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
                    .stroke(theme.shellOutline, lineWidth: MenuPopoverTheme.shellOutlineWidth)
            }
            .shadow(
                color: theme.shellShadow,
                radius: MenuPopoverTheme.shellShadowRadius,
                y: MenuPopoverTheme.shellShadowY
            )
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
