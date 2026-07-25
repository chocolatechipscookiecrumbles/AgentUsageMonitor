import SwiftUI

struct MenuPopoverChrome<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = 0

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
            // Measure the shell's real height so the host window can track it.
            // `MenuBarExtra(.window)` only re-measures its intrinsic height on
            // discrete events (e.g. a tab switch); it does not follow in-place
            // growth when a conditional row appears (e.g. the connection
            // recovery card), which otherwise leaves the window too short and
            // the footer drawn over the taller content.
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MenuPopoverContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(MenuPopoverContentHeightKey.self) { contentHeight = $0 }
            // Clears the host window so this rounded shell is the only visible
            // piece; the window server supplies a matching rounded shadow, so
            // the chrome carries no separate SwiftUI shadow of its own. Also
            // resizes the host to `contentHeight` so the popover scales with its
            // contents instead of clipping them.
            .background(MenuPopoverWindowConfigurator(contentHeight: contentHeight))
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}

/// The measured height of the popover shell, propagated up to the window
/// configurator so it can size the host to fit.
private struct MenuPopoverContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
