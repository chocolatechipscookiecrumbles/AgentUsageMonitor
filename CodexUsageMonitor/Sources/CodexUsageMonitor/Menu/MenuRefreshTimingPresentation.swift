import Foundation

struct MenuRefreshTimingPresentation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case refreshing
        case scheduled(nextRefreshAt: Date)
        case scheduling
    }

    let lastRefreshAt: Date
    let phase: Phase

    init(lastRefreshAt: Date, refreshState: RefreshState, nextRefreshAt: Date?) {
        self.lastRefreshAt = lastRefreshAt
        phase = switch refreshState {
        case .refreshing:
            .refreshing
        case .idle, .failed:
            nextRefreshAt.map(Phase.scheduled) ?? .scheduling
        }
    }
}
