import SwiftUI

/// A slim recovery strip shown on any provider tab when macOS notification
/// permission has been denied, so the path to re-enable it stays one click away
/// without leaving the popover. Notifications are app-wide rather than
/// per-provider, so both tabs render it; it opens macOS System Settings, which
/// is the only place a denied permission can be restored.
struct NotificationPermissionStrip: View {
    let openNotificationSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
            Text("Notifications are disabled in System Settings.")
                .font(.caption)
                .foregroundStyle(theme.warning)
                .lineLimit(MenuPopoverTheme.maximumSupportingLines)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open System Notification Settings", action: openNotificationSettings)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuPopoverTheme.warningStripHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.warningStripVerticalPadding)
        .background(theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
