import SwiftUI

struct CodexUsageWindowCard: View {
    let windows: [CodexMenuPresentation.Window]
    let isCached: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                if index > 0 {
                    Rectangle()
                        .fill(theme.divider)
                        .frame(height: MenuPopoverTheme.dividerHeight)
                        .padding(.horizontal, MenuPopoverTheme.windowRowDividerInset)
                }

                CodexUsageWindowRow(window: window)
                    .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
                    .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
            }
        }
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
        .opacity(isCached ? 0.75 : 1)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
