import AppKit
import SwiftUI

struct ProviderSwitchWindowProbe: NSViewRepresentable {
    let provider: AgentProvider

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(provider: provider)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.provider = provider
        nsView.observeCurrentWindow()
    }

    final class ProbeView: NSView {
        var provider: AgentProvider
        private weak var observedWindow: NSWindow?

        init(provider: AgentProvider) {
            self.provider = provider
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observeCurrentWindow()
        }

        func observeCurrentWindow() {
            guard ProviderSwitchTrace.isEnabled else { return }
            guard observedWindow !== window else { return }
            NotificationCenter.default.removeObserver(self)
            observedWindow = window
            guard let window else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }

        @objc private func windowDidResize(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            ProviderSwitchTrace.record(
                surface: .menuPopover,
                phase: .windowResized,
                provider: provider,
                detail: NSStringFromRect(window.frame)
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
