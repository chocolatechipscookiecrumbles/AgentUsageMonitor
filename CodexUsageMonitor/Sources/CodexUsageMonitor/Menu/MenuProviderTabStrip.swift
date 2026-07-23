import SwiftUI

struct MenuProviderTabStrip: View {
    let providers: [AgentProvider]
    @Binding var selection: AgentProvider

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredProvider: AgentProvider?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(providers) { provider in
                Button(provider.tabTitle) {
                    selection = provider
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(selection == provider ? theme.accent : theme.secondaryText)
                // The whole equal-width column is the target, not just the text,
                // so the tab is easy to hit; the hover fill makes that area read.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .background(hoveredProvider == provider ? theme.hoverBackground : .clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selection == provider ? theme.accent : .clear)
                        .frame(height: MenuPopoverTheme.tabIndicatorHeight)
                }
                .onHover { hovering in
                    if hovering {
                        hoveredProvider = provider
                    } else if hoveredProvider == provider {
                        hoveredProvider = nil
                    }
                }
                .accessibilityAddTraits(selection == provider ? .isSelected : [])
            }
        }
        .frame(height: MenuPopoverTheme.tabStripHeight)
        .background {
            ZStack(alignment: .bottom) {
                theme.tabStripBackground

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: MenuPopoverTheme.dividerHeight)
            }
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
