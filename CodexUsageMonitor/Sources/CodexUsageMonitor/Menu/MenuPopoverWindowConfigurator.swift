import AppKit
import SwiftUI

/// Makes the `MenuBarExtra(.window)` host window transparent so only the rounded
/// `MenuPopoverChrome` shell is visible.
///
/// Without this, the system window keeps its own opaque, squarer background and
/// shadow behind our rounded shell — which shows through at the four corners as
/// stray corner artifacts. Clearing the background (and letting the window
/// server shape the shadow from the shell's rounded, non-transparent content)
/// leaves a single rounded piece.
struct MenuPopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.configure(nsView.window) }
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // The window server draws the shadow from the shell's rounded content
        // (the corners are transparent), so it matches the shell instead of the
        // square window — hence no separate SwiftUI shadow on the chrome.
        window.hasShadow = true
    }
}
