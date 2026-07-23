import SwiftUI

struct StatusPill: View {
    let status: MenuPopoverStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MenuPopoverTheme.statusPillSpacing) {
            Circle()
                .fill(tint)
                .frame(
                    width: MenuPopoverTheme.statusDotSize,
                    height: MenuPopoverTheme.statusDotSize
                )

            Text(status.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, MenuPopoverTheme.statusPillHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.statusPillVerticalPadding)
        .background(theme.statusBackground(status), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage status")
        .accessibilityValue(status.title)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }

    private var tint: Color {
        theme.statusTint(status)
    }
}
