import SwiftUI

struct MenuActionFooter: View {
    let isRefreshing: Bool
    let refresh: () -> Void
    let openNotificationSettings: () -> Void
    let openPreferences: () -> Void
    let quit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: MenuPopoverTheme.dividerHeight)

            VStack(spacing: 0) {
                MenuActionRow(
                    isRefreshing ? "Refreshing…" : "Refresh Now",
                    systemImage: "arrow.clockwise",
                    action: refresh
                )
                .disabled(isRefreshing)

                MenuActionRow(
                    "Notification Settings",
                    systemImage: "bell",
                    action: openNotificationSettings
                )

                MenuActionRow(
                    "Preferences…",
                    systemImage: "gearshape",
                    action: openPreferences
                )

                MenuActionRow(
                    "Quit Codex Usage Monitor",
                    systemImage: "xmark",
                    action: quit
                )
            }
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
