import AppKit

/// Borderless, non-activating menu window: it can become key for keyboard
/// focus and Escape while the frontmost app stays active.
final class MenuPanel: NSPanel {
    var onCancel: () -> Void = {}

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: MenuPopoverTheme.popoverWidth, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        collectionBehavior = [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

/// Opens Settings and quits on behalf of the panel. The panel is standalone
/// AppKit, so it has no scene-backed `openSettings` action; it invokes the
/// command the SwiftUI Settings scene installs in the application menu.
@MainActor
struct MenuCommandRouter {
    let dismiss: () -> Void
    let settings: AppSettings?

    func openSettings(tab: SettingsTab) {
        dismiss()
        settings?.selectedSettingsTab = tab
        // The panel is non-activating; Settings needs the app frontmost.
        NSApp.activate(ignoringOtherApps: true)
        if let menu = NSApp.mainMenu?.items.first?.submenu {
            menu.update()
            if let index = menu.items.firstIndex(where: {
                $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command && $0.isEnabled
            }) {
                menu.performActionForItem(at: index)
                return
            }
        }
        let alert = NSAlert()
        alert.messageText = "Couldn’t open Settings"
        alert.informativeText = "Quit this build and open Settings in your usual Agent Monitor app."
        alert.runModal()
    }

    func quit() {
        dismiss()
        NSApp.terminate(nil)
    }
}
