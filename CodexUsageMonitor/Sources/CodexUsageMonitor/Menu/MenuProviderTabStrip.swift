import SwiftUI

struct MenuProviderTabStrip: View {
    let providers: [AgentProvider]
    @Binding var selection: AgentProvider

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredProvider: AgentProvider?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(providers) { provider in
                Button {
                    selection = provider
                } label: {
                    // The frame and content shape live inside the label so the
                    // plain button owns the whole equal-width column as its hit
                    // target, not just the text. `maxWidth: .infinity` also lets
                    // each button divide the strip width equally.
                    Text(provider.tabTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selection == provider ? theme.accent : theme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
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
