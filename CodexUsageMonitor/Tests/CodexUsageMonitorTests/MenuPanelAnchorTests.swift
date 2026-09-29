import AppKit
import SwiftUI
import XCTest
@testable import CodexUsageMonitor

/// The trial shell centered itself in a taller window, moving the tabs and
/// header by half the height difference (70 pt here) for a frame on every
/// switch (ADR 0004). This failed against the archived `MenuTrialShell`.
@MainActor
final class MenuPanelAnchorTests: XCTestCase {
    func testShellStaysTopAnchoredInTallerWindow() throws {
        let model = MenuPanelModel(state: MenuPanelState(
            selection: .codex,
            snapshot: .fixture(provider: .codex, index: 0),
            keyboardShortcutsEnabled: false,
            diagnosticLabel: "Diagnostic"
        ), maximumHeight: 860)
        let root = MenuPanelRoot(model: model, actions: .inert, onSettledHeight: { _ in })
        let fitted = try viewportMinY(root, extraHeight: 0)
        let taller = try viewportMinY(root, extraHeight: 140)
        XCTAssertEqual(taller, fitted, accuracy: 0.5,
                       "A window taller than the shell must not move the tabs and header")
    }

    private func viewportMinY<Root: View>(_ root: Root, extraHeight: CGFloat) throws -> CGFloat {
        // Measure with default sizing options; with none, fittingSize is zero.
        let fitted = NSHostingView(rootView: root).fittingSize.height
        XCTAssertGreaterThan(fitted, 200, "Fixture shell must have real content")
        // The panel host resizes the window itself, so its hosting view reports no size.
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: fitted + extraHeight),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 340, height: fitted + extraHeight)
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        func scrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
        }
        let scroll = try XCTUnwrap(scrollView(in: host), "No provider viewport")
        return scroll.convert(scroll.bounds, to: host).minY
    }
}
