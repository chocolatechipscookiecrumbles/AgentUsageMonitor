import SwiftUI

struct MenuProviderTabStrip: View {
    let providers: [AgentProvider]
    @Binding var selection: AgentProvider

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(providers) { provider in
                Button(provider.tabTitle) {
                    selection = provider
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(selection == provider ? theme.accent : theme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selection == provider ? theme.accent : .clear)
                        .frame(height: MenuPopoverTheme.tabIndicatorHeight)
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
