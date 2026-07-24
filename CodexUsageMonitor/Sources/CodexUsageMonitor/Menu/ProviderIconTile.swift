import SwiftUI

struct ProviderIconTile: View {
    let provider: AgentProvider

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AgentSettingsIcon(
            provider: provider,
            slotSize: MenuPopoverTheme.providerIconTileSize,
            artworkMaxSize: artworkMaxSize
        )
        .background(
            theme.providerTileBackground(provider),
            in: RoundedRectangle(cornerRadius: MenuPopoverTheme.providerIconTileCornerRadius)
        )
        .clipShape(RoundedRectangle(cornerRadius: MenuPopoverTheme.providerIconTileCornerRadius))
        .accessibilityHidden(true)
    }

    /// Codex's mark already carries its own square background, so it fills the
    /// whole tile (clipped to the tile's rounded corners) with no extra
    /// padding. Providers with a transparent glyph — Claude, Copilot — keep the
    /// inset so the mark breathes inside the tint.
    private var artworkMaxSize: CGFloat {
        switch provider {
        case .codex:
            MenuPopoverTheme.providerIconTileSize
        case .claudeCode, .githubCopilot:
            MenuPopoverTheme.providerIconArtworkSize
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
