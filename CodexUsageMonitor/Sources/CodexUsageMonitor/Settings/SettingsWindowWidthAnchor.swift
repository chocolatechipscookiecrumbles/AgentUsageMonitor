import AppKit
import SwiftUI

struct SettingsWindowWidthAnchor: NSViewRepresentable {
    let contentSize: CGSize

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onWindowAvailable = { window in
            context.coordinator.apply(contentSize, to: window)
        }
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        if let window = view.window {
            context.coordinator.apply(contentSize, to: window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class AnchorView: NSView {
        var onWindowAvailable: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if let window {
                onWindowAvailable?(window)
            }
        }
    }

    @MainActor
    final class Coordinator {
        private var lastContentSize: CGSize?

        func apply(_ contentSize: CGSize, to window: NSWindow) {
            guard lastContentSize != contentSize else { return }

            let leftEdge = window.frame.minX
            window.setContentSize(contentSize)
            window.setFrameOrigin(NSPoint(x: leftEdge, y: window.frame.minY))
            lastContentSize = contentSize
        }
    }
}
