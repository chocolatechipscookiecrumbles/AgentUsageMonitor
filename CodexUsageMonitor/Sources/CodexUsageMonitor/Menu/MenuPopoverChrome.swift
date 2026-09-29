import SwiftUI

struct MenuPopoverChrome<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var shellHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(width: MenuPopoverTheme.popoverWidth)
                .fixedSize(horizontal: false, vertical: true)
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
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: MenuPopoverShellHeightKey.self, value: proxy.size.height)
                    }
                }

            Color.clear
                .contentShape(.rect)
                .onTapGesture { dismiss() }
                .accessibilityHidden(true)
        }
        .frame(height: MenuPopoverTheme.availablePopoverHeight)
        .onPreferenceChange(MenuPopoverShellHeightKey.self) { shellHeight = $0 }
        .background(MenuPopoverWindowConfigurator(
            contentHeight: MenuPopoverTheme.availablePopoverHeight,
            visibleHeight: shellHeight
        ))
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}

private struct MenuPopoverShellHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
