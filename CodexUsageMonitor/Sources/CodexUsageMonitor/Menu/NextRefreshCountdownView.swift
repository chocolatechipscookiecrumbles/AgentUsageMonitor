import AppKit
import SwiftUI

struct NextRefreshCountdownView: NSViewRepresentable {
    let lastRefreshAt: Date
    let nextRefreshAt: Date?
    let isRefreshing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        context.coordinator.attach(label)
        context.coordinator.update(
            lastRefreshAt: lastRefreshAt,
            nextRefreshAt: nextRefreshAt,
            isRefreshing: isRefreshing
        )
        return label
    }

    func updateNSView(_ label: NSTextField, context: Context) {
        context.coordinator.update(
            lastRefreshAt: lastRefreshAt,
            nextRefreshAt: nextRefreshAt,
            isRefreshing: isRefreshing
        )
    }

    static func dismantleNSView(_ label: NSTextField, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private weak var label: NSTextField?
        private var timer: Timer?
        private var lastRefreshAt = Date.now
        private var nextRefreshAt: Date?
        private var isRefreshing = false

        func attach(_ label: NSTextField) {
            self.label = label
        }

        func update(lastRefreshAt: Date, nextRefreshAt: Date?, isRefreshing: Bool) {
            self.lastRefreshAt = lastRefreshAt
            self.nextRefreshAt = nextRefreshAt
            self.isRefreshing = isRefreshing
            render(at: .now)
            updateTimer()
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }

        private func updateTimer() {
            guard !isRefreshing, let nextRefreshAt, nextRefreshAt > .now else {
                stop()
                return
            }
            guard timer == nil else { return }
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.render(at: .now)
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func render(at date: Date) {
            let lastRefresh = lastRefreshAt.formatted(date: .omitted, time: .shortened)
            let text: String
            if isRefreshing {
                text = "Last refresh: \(lastRefresh) · Refreshing…"
            } else if let nextRefreshAt {
                let remaining = max(0, Int(ceil(nextRefreshAt.timeIntervalSince(date))))
                text = "Last refresh: \(lastRefresh) · Next: \(remaining / 60):\(String(format: "%02d", remaining % 60))"
            } else {
                text = "Last refresh: \(lastRefresh) · Scheduling…"
            }
            label?.stringValue = text
            label?.setAccessibilityLabel(text)
        }
    }
}
