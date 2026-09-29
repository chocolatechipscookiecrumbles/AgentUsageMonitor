import SwiftUI

/// Claude's counterpart to the Codex cached strip: whenever a read is not
/// live, the notice makes the staleness visible above the windows so a cached
/// or passive result is never mistaken for current.
struct ClaudeStalenessStrip: View {
    let notice: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.warningStripSpacing) {
            Image(systemName: "clock")
                .font(.system(size: MenuPopoverTheme.warningStripIconSize, weight: .medium))

            Text(notice)
                .font(.caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.warning)
        .padding(.horizontal, MenuPopoverTheme.warningStripHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.warningStripVerticalPadding)
        .background(theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
