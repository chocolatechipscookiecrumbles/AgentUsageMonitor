import AppKit
import SwiftUI
import XCTest
@testable import CodexUsageMonitor

/// Switching General → Notifications replaced the page's whole native scroll
/// host (a new NSScrollView and its controls) in one transaction, which is when
/// the Settings window showed duplicated and displaced text for a frame or two.
/// The destination switch must only change which retained page is visible.
@MainActor
final class SettingsDestinationStackTests: XCTestCase {
    func testSwitchingDestinationsKeepsEveryPageScrollHost() {
        let host = NSHostingView(rootView: stack(.general))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        settle(host)
        let before = scrollViews(in: host)

        host.rootView = stack(.notifications)
        settle(host)
        let after = scrollViews(in: host)

        XCTAssertFalse(before.isEmpty)
        XCTAssertTrue(before.isSubset(of: after),
                      "A destination switch must not tear down and rebuild a page's scroll host")
    }

    /// Like `SettingsDetailView`, each destination is a different page type
    /// selected by a `switch`, each owning its own scroll host.
    private func stack(_ selection: SettingsTab) -> SettingsDestinationStack<some View> {
        SettingsDestinationStack(selection: selection) { tab in
            switch tab {
            case .general: StandInPage(title: "General", rows: 8)
            case .notifications: OtherStandInPage(title: "Notifications")
            default: StandInPage(title: tab.rawValue, rows: 3)
            }
        }
    }

    private func settle(_ host: NSView) {
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    private func scrollViews(in view: NSView) -> Set<ObjectIdentifier> {
        var found = Set<ObjectIdentifier>()
        if view is NSScrollView { found.insert(ObjectIdentifier(view)) }
        for subview in view.subviews { found.formUnion(scrollViews(in: subview)) }
        return found
    }
}

private struct StandInPage: View {
    let title: String
    let rows: Int

    var body: some View {
        ScrollView {
            VStack { ForEach(0..<rows, id: \.self) { Text("\(title) \($0)") } }
                .frame(maxWidth: .infinity, minHeight: 600)
        }
    }
}

private struct OtherStandInPage: View {
    let title: String

    var body: some View {
        ScrollView {
            Toggle(title, isOn: .constant(true)).frame(maxWidth: .infinity, minHeight: 600)
        }
    }
}
