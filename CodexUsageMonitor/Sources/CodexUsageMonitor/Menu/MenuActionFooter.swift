import SwiftUI

struct MenuActionFooter: View {
    @ObservedObject var settings: AppSettings
    let isRefreshing: Bool
    /// False on a connect-only tab: there is nothing to refresh, and the row
    /// must read as unavailable rather than quietly enrolling the provider.
    var isRefreshEnabled = true
    let refresh: () -> Void
    let openNotificationSettings: () -> Void
    let openPreferences: () -> Void
    let quit: () -> Void

    var body: some View {
        MenuActionFooterRows(
            keyboardShortcutsEnabled: settings.keyboardShortcutsEnabled,
            isRefreshing: isRefreshing,
            isRefreshEnabled: isRefreshEnabled,
            allowsCommands: true,
            refresh: refresh,
            openNotificationSettings: openNotificationSettings,
            openPreferences: openPreferences,
            quit: quit
        )
    }
}

struct MenuActionFooterRows: View {
    let keyboardShortcutsEnabled: Bool
    let isRefreshing: Bool
    var isRefreshEnabled = true
    var allowsCommands = true
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
                    shortcut: shortcut(.refresh),
                    action: refresh
                )
                .disabled(isRefreshing || !isRefreshEnabled || !allowsCommands)

                MenuActionRow(
                    "Notification Settings",
                    systemImage: "bell",
                    shortcut: shortcut(.notificationSettings),
                    action: openNotificationSettings
                )
                .disabled(!allowsCommands)

                MenuActionRow(
                    "Preferences…",
                    systemImage: "gearshape",
                    shortcut: shortcut(.preferences),
                    action: openPreferences
                )
                .disabled(!allowsCommands)

                MenuActionRow(
                    "Quit Agent Monitor",
                    systemImage: "xmark",
                    shortcut: shortcut(.quit),
                    action: quit
                )
            }
        }
    }

    /// The preference governs registration as well as display, so an unlisted
    /// shortcut is also an unbound one.
    private func shortcut(_ shortcut: MenuActionShortcut) -> MenuActionShortcut? {
        keyboardShortcutsEnabled ? shortcut : nil
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
