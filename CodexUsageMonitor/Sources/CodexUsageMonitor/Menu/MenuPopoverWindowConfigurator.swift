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
    /// The measured height of the popover shell. When it changes, the host is
    /// resized to match so the popover scales with its contents.
    var contentHeight: CGFloat = 0

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let height = contentHeight
        DispatchQueue.main.async { Self.configure(view.window, contentHeight: height) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let height = contentHeight
        DispatchQueue.main.async { Self.configure(nsView.window, contentHeight: height) }
    }

    private static func configure(_ window: NSWindow?, contentHeight: CGFloat) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // The window server draws the shadow from the shell's rounded content
        // (the corners are transparent), so it matches the shell instead of the
        // square window — hence no separate SwiftUI shadow on the chrome.
        window.hasShadow = true

        // Track the content's height so conditionally-shown rows grow the
        // popover instead of drawing beneath the footer. The top edge stays
        // anchored under the status item (matching MenuBarExtra's own resize),
        // and the width is left to SwiftUI. Guarded so equal-height states — the
        // common tab switch — are a no-op and do not reintroduce a resize on
        // selection.
        guard contentHeight > 0 else { return }
        let current = window.frame
        guard abs(current.height - contentHeight) > 0.5 else { return }
        var frame = current
        frame.size.height = contentHeight
        frame.origin.y = current.maxY - contentHeight
        window.setFrame(frame, display: true)
    }
}
