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
            // Clears the host window so this rounded shell is the only visible
            // piece; the window server supplies a matching rounded shadow, so
            // the chrome carries no separate SwiftUI shadow of its own.
            .background(MenuPopoverWindowConfigurator())
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
