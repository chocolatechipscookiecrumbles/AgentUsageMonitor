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
    /// Stable transparent host height; the visible shell may be shorter.
    var contentHeight: CGFloat = 0
    var visibleHeight: CGFloat = 0

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let height = contentHeight
        let visible = visibleHeight
        DispatchQueue.main.async { Self.configure(view.window, contentHeight: height, visibleHeight: visible) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let height = contentHeight
        let visible = visibleHeight
        DispatchQueue.main.async { Self.configure(nsView.window, contentHeight: height, visibleHeight: visible) }
    }

    private static func configure(_ window: NSWindow?, contentHeight: CGFloat, visibleHeight: CGFloat) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // The window server draws the shadow from the shell's rounded content
        // (the corners are transparent), so it matches the shell instead of the
        // square window — hence no separate SwiftUI shadow on the chrome.
        window.hasShadow = true

        // Keep the host fixed across provider switches. The visible shell
        // changes height inside this transparent window without resizing it.
        guard contentHeight > 0 else { return }
        let current = window.frame
        if abs(current.height - contentHeight) > 0.5 {
            var frame = current
            frame.size.height = contentHeight
            frame.origin.y = current.maxY - contentHeight
            window.setFrame(frame, display: true)
        }

        if visibleHeight > 0, let contentView = window.contentView {
            contentView.wantsLayer = true
            let bounds = contentView.bounds
            let height = min(visibleHeight, bounds.height)
            let rect = CGRect(
                x: 0,
                y: contentView.isFlipped ? 0 : bounds.height - height,
                width: bounds.width,
                height: height
            )
            let mask = CAShapeLayer()
            mask.frame = bounds
            mask.path = CGPath(
                roundedRect: rect,
                cornerWidth: MenuPopoverTheme.shellCornerRadius,
                cornerHeight: MenuPopoverTheme.shellCornerRadius,
                transform: nil
            )
            contentView.layer?.mask = mask
        }
    }
}
