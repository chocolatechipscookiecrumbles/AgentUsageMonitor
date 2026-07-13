import SwiftUI

struct NextRefreshCountdownView: View {
    let lastRefreshAt: Date
    let nextRefreshAt: Date?
    let isRefreshing: Bool

    var body: some View {
        if isRefreshing {
            Text("Last refresh: \(lastRefreshName) · Refreshing…")
                .font(.caption)
        } else if let nextRefreshAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(scheduledText(nextRefreshAt: nextRefreshAt, at: context.date))
                    .font(.caption)
            }
        } else {
            Text("Last refresh: \(lastRefreshName) · Scheduling…")
                .font(.caption)
        }
    }

    private var lastRefreshName: String {
        lastRefreshAt.formatted(date: .omitted, time: .shortened)
    }

    private func scheduledText(nextRefreshAt: Date, at date: Date) -> String {
        let remaining = max(0, Int(ceil(nextRefreshAt.timeIntervalSince(date))))
        return "Last refresh: \(lastRefreshName) · Next: \(remaining / 60):\(String(format: "%02d", remaining % 60))"
    }
}
