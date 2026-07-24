import SwiftUI

struct MenuProviderHeader: View {
    let provider: AgentProvider
    let presentation: MenuProviderHeaderPresentation

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MenuPopoverTheme.headerSpacing) {
            ProviderIconTile(provider: provider)

            VStack(alignment: .leading, spacing: MenuPopoverTheme.headerTextSpacing) {
                Text(presentation.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Text(presentation.subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }
            .lineLimit(1)

            Spacer(minLength: MenuPopoverTheme.headerSpacing)

            StatusPill(status: presentation.status)
        }
        .padding(.horizontal, MenuPopoverTheme.headerHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.headerVerticalPadding)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
