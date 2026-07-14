import Combine
import Foundation

@MainActor
final class RefreshCountdownClock: ObservableObject {
    @Published private(set) var text: String

    private var timer: Timer?
    private var lastRefreshAt: Date
    private var nextRefreshAt: Date?
    private var isRefreshing: Bool

    init(lastRefreshAt: Date, nextRefreshAt: Date?, isRefreshing: Bool) {
        self.lastRefreshAt = lastRefreshAt
        self.nextRefreshAt = nextRefreshAt
        self.isRefreshing = isRefreshing
        text = ""
        render(at: .now)
        updateTimer()
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }

    func update(lastRefreshAt: Date, nextRefreshAt: Date?, isRefreshing: Bool) {
        self.lastRefreshAt = lastRefreshAt
        self.nextRefreshAt = nextRefreshAt
        self.isRefreshing = isRefreshing
        render(at: .now)
        updateTimer()
    }

    private func updateTimer() {
        guard !isRefreshing, let nextRefreshAt, nextRefreshAt > .now else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.render(at: .now)
                self.updateTimer()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func render(at date: Date) {
        let lastRefresh = lastRefreshAt.formatted(date: .omitted, time: .shortened)
        let newText: String
        if isRefreshing {
            newText = "Last refresh: \(lastRefresh) · Refreshing…"
        } else if let nextRefreshAt {
            let remaining = max(0, Int(ceil(nextRefreshAt.timeIntervalSince(date))))
            newText = "Last refresh: \(lastRefresh) · Next: \(remaining / 60):\(String(format: "%02d", remaining % 60))"
        } else {
            newText = "Last refresh: \(lastRefresh) · Scheduling…"
        }
        if newText != text {
            text = newText
        }
    }
}
