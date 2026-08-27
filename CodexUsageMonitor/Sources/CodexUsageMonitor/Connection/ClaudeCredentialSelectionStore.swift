import Combine
import Foundation

/// Persists only the user's chosen credential route. No secret material is
/// stored in defaults; setup-token material remains in the app-owned Keychain.
@MainActor
final class ClaudeCredentialSelectionStore: ObservableObject {
    static let defaultsKey = "claude.credential-method.v1"

    @Published private(set) var selectedMethod: ClaudeSignInMethod?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, legacyEnrollmentEnabled: Bool = false) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let method = ClaudeSignInMethod(rawValue: rawValue) {
            selectedMethod = method
        } else if legacyEnrollmentEnabled {
            // Existing enrolled installs previously used Claude Code's item.
            selectedMethod = .claudeCodeCredentials
            defaults.set(ClaudeSignInMethod.claudeCodeCredentials.rawValue, forKey: Self.defaultsKey)
        } else {
            selectedMethod = nil
        }
    }

    func select(_ method: ClaudeSignInMethod) {
        selectedMethod = method
        defaults.set(method.rawValue, forKey: Self.defaultsKey)
    }

    func clear() {
        selectedMethod = nil
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
