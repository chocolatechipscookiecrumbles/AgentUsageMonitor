import Combine
import Foundation

/// The single owner of app-local provider consent.
///
/// Views, monitors, and connection controllers read enrollment from here rather
/// than each deciding for itself what "connected" means. The store writes only
/// on an explicit `enable`/`disable`, so merely reading a provider's state on
/// launch can never record a preference the user did not express.
@MainActor
final class ProviderEnrollmentStore: ObservableObject {
    @Published private(set) var states: [AgentProvider: ProviderEnrollmentState]

    private let defaults: UserDefaults

    /// Persisted per provider under a stable, readable suffix. Deliberately not
    /// `AgentProvider.rawValue`: the raw value is a Swift identifier that a
    /// rename would silently change, and this key has to outlive refactors.
    private static func key(for provider: AgentProvider) -> String {
        let suffix = switch provider {
        case .codex: "codex"
        case .claudeCode: "claude-code"
        case .githubCopilot: "github-copilot"
        }
        return "provider.enrollment.\(suffix)"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded: [AgentProvider: ProviderEnrollmentState] = [:]
        for provider in AgentProvider.allCases {
            // Absent *and* unrecognized both resolve to `.notRequested`. An
            // unknown stored value is either a downgrade or a corrupted write;
            // in both cases the safe reading is that this build has no consent
            // it can act on.
            loaded[provider] = defaults.string(forKey: Self.key(for: provider))
                .flatMap(ProviderEnrollmentState.init(rawValue:))
                ?? .notRequested
        }
        states = loaded
        Self.removeLegacyDisconnectKeys(from: defaults)
    }

    func state(for provider: AgentProvider) -> ProviderEnrollmentState {
        states[provider] ?? .notRequested
    }

    func isEnabled(_ provider: AgentProvider) -> Bool {
        state(for: provider) == .enabled
    }

    func enable(_ provider: AgentProvider) {
        set(.enabled, for: provider)
    }

    func disable(_ provider: AgentProvider) {
        set(.disabled, for: provider)
    }

    private func set(_ state: ProviderEnrollmentState, for provider: AgentProvider) {
        guard states[provider] != state else { return }
        states[provider] = state
        defaults.set(state.rawValue, forKey: Self.key(for: provider))
    }

    /// 0.0.1 stored `codex.disconnected` / `claude.disconnected`, which recorded
    /// only whether the user had *turned a provider off*. An absent or `false`
    /// value therefore proves nothing about consent — it is the same value a
    /// user who never opened the app would have — so it is not migrated to
    /// `.enabled`. The keys are removed rather than left to rot, because keeping
    /// two overlapping notions of "disconnected" is what made the released
    /// behavior ambiguous. Neither provider CLI is signed out.
    private static func removeLegacyDisconnectKeys(from defaults: UserDefaults) {
        for key in ["codex.disconnected", "claude.disconnected"] {
            guard defaults.object(forKey: key) != nil else { continue }
            defaults.removeObject(forKey: key)
        }
    }
}
