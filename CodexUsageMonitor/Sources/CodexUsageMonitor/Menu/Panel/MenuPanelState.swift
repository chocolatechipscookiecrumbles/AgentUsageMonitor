import Foundation

/// Everything `MenuSurface` renders, as values. The panel controller publishes
/// it only after the window can hold it (ADR 0004).
struct MenuPanelState {
    var selection: AgentProvider
    var snapshot: MenuContentSnapshot
    var keyboardShortcutsEnabled: Bool
    /// Fixture replay only: names the synthetic state and disables account actions.
    var diagnosticLabel: String?

    static func placeholder() -> Self {
        Self(
            selection: .codex,
            snapshot: .fixture(provider: .codex, index: 0),
            keyboardShortcutsEnabled: false,
            diagnosticLabel: nil
        )
    }
}

/// Commands the surface can issue. Selection is an intent: the controller
/// decides when the new provider is committed.
struct MenuSurfaceActions {
    var select: (AgentProvider) -> Void
    var refresh: () -> Void
    var connect: () -> Void
    var signInWithBrowser: () -> Void
    var signInWithCLI: () -> Void
    var openSystemNotificationSettings: () -> Void
    var openNotificationSettings: () -> Void
    var openPreferences: () -> Void
    var nextFixture: () -> Void
    var quit: () -> Void
    var dismiss: () -> Void

    /// Identical layout with no side effects, for offscreen measurement.
    static var inert: Self {
        Self(
            select: { _ in }, refresh: {}, connect: {}, signInWithBrowser: {}, signInWithCLI: {},
            openSystemNotificationSettings: {}, openNotificationSettings: {}, openPreferences: {},
            nextFixture: {}, quit: {}, dismiss: {}
        )
    }
}
