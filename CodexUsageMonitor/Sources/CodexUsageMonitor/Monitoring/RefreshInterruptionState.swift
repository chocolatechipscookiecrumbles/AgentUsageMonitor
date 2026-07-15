import Foundation

struct RefreshInterruptionEpisode: Codable, Equatable, Sendable {
    let id: String
    let firstFailureAt: Date
    let lastConfirmedAt: Date?
    var failureCount: Int

    static func start(firstFailureAt: Date, lastConfirmedAt: Date?) -> Self {
        let anchor = lastConfirmedAt ?? firstFailureAt
        let identifier = String(Int64(anchor.timeIntervalSince1970 * 1_000), radix: 36)
        return Self(
            id: identifier,
            firstFailureAt: firstFailureAt,
            lastConfirmedAt: lastConfirmedAt,
            failureCount: 1
        )
    }
}

enum RefreshInterruptionState: Equatable, Sendable {
    case healthy
    case observing(RefreshInterruptionEpisode)
    case backedOff(RefreshInterruptionEpisode)

    var episode: RefreshInterruptionEpisode? {
        switch self {
        case .healthy: nil
        case .observing(let episode), .backedOff(let episode): episode
        }
    }

    var isActive: Bool { episode != nil }
}

enum RefreshInterruptionTransition: Equatable, Sendable {
    case none
    case alertEligible(RefreshInterruptionEpisode)
    case recovered(RefreshInterruptionEpisode)
}

private struct StoredRefreshInterruption: Codable {
    let episode: RefreshInterruptionEpisode
    let isBackedOff: Bool
}

final class RefreshInterruptionStore {
    private let defaults: UserDefaults
    private let key = "monitor.refreshInterruption"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RefreshInterruptionState {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(StoredRefreshInterruption.self, from: data)
        else { return .healthy }
        return stored.isBackedOff ? .backedOff(stored.episode) : .observing(stored.episode)
    }

    func save(_ state: RefreshInterruptionState) {
        let stored: StoredRefreshInterruption?
        switch state {
        case .healthy:
            stored = nil
        case .observing(let episode):
            stored = StoredRefreshInterruption(episode: episode, isBackedOff: false)
        case .backedOff(let episode):
            stored = StoredRefreshInterruption(episode: episode, isBackedOff: true)
        }
        guard let stored, let data = try? JSONEncoder().encode(stored) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
