import SwiftUI

struct MenuRefreshTimingView: View {
    let presentation: MenuRefreshTimingPresentation

    var body: some View {
        Text(text)
            .font(.caption)
            .accessibilityLabel(text)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var text: String {
        let lastRefresh = presentation.lastRefreshAt.formatted(date: .omitted, time: .shortened)
        switch presentation.phase {
        case .refreshing:
            return "Last refresh: \(lastRefresh) · Refreshing…"
        case .scheduled(let nextRefreshAt):
            let nextRefresh = nextRefreshAt.formatted(date: .omitted, time: .shortened)
            return "Last refresh: \(lastRefresh) · Next refresh: \(nextRefresh)"
        case .scheduling:
            return "Last refresh: \(lastRefresh) · Scheduling…"
        }
    }
}
