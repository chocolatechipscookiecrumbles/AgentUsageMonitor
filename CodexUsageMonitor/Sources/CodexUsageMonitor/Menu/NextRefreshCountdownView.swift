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
            HStack(spacing: 0) {
                Text("Last refresh: \(lastRefreshName) · Next: ")
                Text(
                    timerInterval: countdownInterval(endingAt: nextRefreshAt),
                    pauseTime: nil,
                    countsDown: true,
                    showsHours: false
                )
            }
            .font(.caption)
        } else {
            Text("Last refresh: \(lastRefreshName) · Scheduling…")
                .font(.caption)
        }
    }

    private var lastRefreshName: String {
        lastRefreshAt.formatted(date: .omitted, time: .shortened)
    }

    private func countdownInterval(endingAt endDate: Date) -> ClosedRange<Date> {
        min(.now, endDate)...endDate
    }
}
