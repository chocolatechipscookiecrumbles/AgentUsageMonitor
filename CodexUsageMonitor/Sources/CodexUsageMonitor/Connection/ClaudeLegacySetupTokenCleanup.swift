import Foundation
import Security

/// One-way cleanup for the retired setup-token experiment. This touches only
/// the Keychain service previously owned by this app. Claude Code's credential
/// is a read-only provider compatibility boundary and is never changed.
actor ClaudeLegacySetupTokenCleanup {
    enum Outcome: Equatable, Sendable {
        case removed
        case alreadyAbsent
        case deferredAccessDenied
        case failed(OSStatus)
    }

    private let serviceName = "AgentUsageMonitor-ClaudeOAuth"
    private let accountName = "setup-token-v1"

    func removeAppOwnedCredential() -> Outcome {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // The outcome is classified for callers without logging any item data.
        // Cleanup is best-effort and never blocks connection or disconnect.
        switch status {
        case errSecSuccess:
            return .removed
        case errSecItemNotFound:
            return .alreadyAbsent
        case errSecInteractionNotAllowed, errSecAuthFailed:
            return .deferredAccessDenied
        default:
            return .failed(status)
        }
    }
}
