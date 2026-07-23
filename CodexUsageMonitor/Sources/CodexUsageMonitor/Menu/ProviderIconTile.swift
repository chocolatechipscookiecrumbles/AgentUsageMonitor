import SwiftUI

struct ProviderIconTile: View {
    let provider: AgentProvider

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AgentSettingsIcon(
            provider: provider,
            slotSize: MenuPopoverTheme.providerIconTileSize,
            artworkMaxSize: MenuPopoverTheme.providerIconArtworkSize
        )
        .background(
            theme.providerTileBackground(provider),
            in: RoundedRectangle(cornerRadius: MenuPopoverTheme.providerIconTileCornerRadius)
        )
        .accessibilityHidden(true)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
