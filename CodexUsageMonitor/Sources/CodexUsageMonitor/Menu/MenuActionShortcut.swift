import SwiftUI

/// The key equivalent for one popover footer command.
///
/// The displayed symbol and the registered shortcut are read from the same
/// case, so a row cannot print `⌘R` while registering something else, and the
/// list in General Settings cannot drift from what the popover actually fires.
enum MenuActionShortcut: String, CaseIterable, Identifiable, Sendable {
    case refresh
    case notificationSettings
    case preferences
    case quit

    var id: String { rawValue }

    /// How the command is named in the Settings list. The popover row supplies
    /// its own title because "Refresh Now" becomes "Refreshing…" mid-refresh.
    var commandTitle: String {
        switch self {
        case .refresh: "Refresh Now"
        case .notificationSettings: "Notification Settings"
        case .preferences: "Preferences…"
        case .quit: "Quit Codex Usage Monitor"
        }
    }

    var key: KeyEquivalent {
        switch self {
        case .refresh: "r"
        // Shifted, so the unmodified "new" slot stays unclaimed.
        case .notificationSettings: "n"
        case .preferences: ","
        case .quit: "q"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .notificationSettings: [.command, .shift]
        case .refresh, .preferences, .quit: .command
        }
    }

    /// Canonical macOS modifier order — ⌃⌥⇧⌘ then the key — so these read the
    /// same way as every other Mac menu.
    var displayString: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols + String(key.character).uppercased()
    }
}
