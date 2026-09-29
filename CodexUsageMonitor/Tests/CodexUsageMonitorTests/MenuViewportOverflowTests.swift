import AppKit
import SwiftUI
import XCTest
@testable import CodexUsageMonitor

@MainActor
final class MenuViewportOverflowTests: XCTestCase {
    func testTallFailureContentStaysBetweenHeaderAndFooter() {
        let root = MenuAdaptiveLayout(selection: .codex, maximumHeight: 860) {
            Color.blue.frame(height: 86)
        } content: {
            Color.orange.frame(height: 800)
        } footer: {
            Color.green.frame(height: 137)
        }
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 340, height: 860)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        func scrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
        }
        guard let scroll = scrollView(in: host) else {
            XCTFail("No native scroll viewport in the menu layout")
            return
        }
        let rect = scroll.convert(scroll.bounds, to: host)
        XCTAssertLessThanOrEqual(rect.height, 637.5, "Failure content must scroll instead of expanding through header/footer")
        XCTAssertGreaterThanOrEqual(rect.minY, 85.5, "Viewport must start below the header")
        XCTAssertLessThanOrEqual(rect.maxY, 723.5, "Viewport must end above the footer")
        XCTAssertGreaterThan(scroll.documentView?.bounds.height ?? 0, rect.height)
    }
}
