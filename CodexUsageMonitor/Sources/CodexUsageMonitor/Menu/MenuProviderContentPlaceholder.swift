import SwiftUI

struct MenuProviderContentPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(
                maxWidth: .infinity,
                minHeight: MenuPopoverTheme.contentPlaceholderHeight
            )
            .background(
                theme.cardBackground,
                in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius)
            )
            .accessibilityHidden(true)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
