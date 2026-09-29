import AppKit
import SwiftUI

/// The status button owns the complete click target; its SwiftUI artwork does
/// not intercept pointer events or create a second accessibility element.
final class MenuStatusHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
