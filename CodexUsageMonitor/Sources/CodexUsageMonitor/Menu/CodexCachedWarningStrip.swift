import SwiftUI

struct CodexCachedWarningStrip: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MenuPopoverTheme.warningStripSpacing) {
            Image(systemName: "clock")
                .font(.system(size: MenuPopoverTheme.warningStripIconSize, weight: .medium))

            Text("Showing Last Confirmed Snapshot")
                .font(.caption.weight(.medium))

            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.warning)
        .padding(.horizontal, MenuPopoverTheme.warningStripHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.warningStripVerticalPadding)
        .background(theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Showing last confirmed quota snapshot")
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
