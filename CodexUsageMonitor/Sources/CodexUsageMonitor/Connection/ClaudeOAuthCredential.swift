import Foundation
import LocalAuthentication
import Security

/// Deliberately NOT Codable, CustomStringConvertible, or
/// CustomDebugStringConvertible — nothing about this type should be
/// persistable or printable by accident. The token lives in Keychain only.
struct ClaudeOAuthCredential: Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: Set<String>
    let subscriptionType: String?
}

enum ClaudeCredentialError: Error, Equatable, Sendable {
    case notFound
    case malformedData
    case interactionNotAllowed
    case accessDenied
    case unexpectedStatus(OSStatus)
}

/// Controls whether a Keychain read may raise macOS's permission dialog.
///
/// Reading Claude Code's own Keychain item from our process is an ACL-gated
/// cross-app access, so it *can* prompt. A prompt is acceptable when the user
/// just pressed a button; it is never acceptable on a scheduled refresh,
/// which would interrupt them on a timer.
enum KeychainPromptPolicy: Equatable, Sendable {
    /// Fail the read rather than prompt. Used for every automatic refresh.
    case never
    /// Allow macOS to prompt. Only ever reached from an explicit user action.
    case userInitiatedOnly
}

protocol ClaudeCredentialProviding: Sendable {
    func resolveCredential(promptPolicy: KeychainPromptPolicy) async throws -> ClaudeCredentialResolution
}

extension ClaudeCredentialProviding {
    /// Defaults to the safe policy so a call site that forgets to specify one
    /// can never introduce a background prompt.
    func loadCredential(promptPolicy: KeychainPromptPolicy = .never) async throws -> ClaudeOAuthCredential {
        try await resolveCredential(promptPolicy: promptPolicy).credential
    }
}

/// Reads Claude Code's own already-issued OAuth credential from the login
/// Keychain (service "Claude Code-credentials"). This app never runs its
/// own sign-in flow and never stores the token anywhere else.
actor ClaudeKeychainCredentialStore: ClaudeCredentialProviding {
    private let rawDataReader: @Sendable (KeychainPromptPolicy) -> Result<Data, ClaudeCredentialError>

    init(serviceName: String = "Claude Code-credentials") {
        self.rawDataReader = { Self.readKeychainData(serviceName: serviceName, promptPolicy: $0) }
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain.
    init(rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>) {
        self.rawDataReader = { _ in rawDataReader() }
    }

    func resolveCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeCredentialResolution {
        switch rawDataReader(promptPolicy) {
        case .success(let data):
            return ClaudeCredentialResolution(
                credential: try Self.parse(data),
                method: .claudeCodeCredentials
            )
        case .failure(let error):
            throw error
        }
    }

    /// Built separately so the prompt policy is directly assertable. A
    /// background read uses a non-interactive authentication context, which
    /// guarantees an automatic refresh cannot pop a dialog.
    static func searchQuery(serviceName: String, promptPolicy: KeychainPromptPolicy) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if promptPolicy == .never {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        return query
    }

    static func error(for status: OSStatus) -> ClaudeCredentialError {
        switch status {
        case errSecItemNotFound:
            .notFound
        case errSecInteractionNotAllowed:
            .interactionNotAllowed
        case errSecAuthFailed, errSecMissingEntitlement:
            .accessDenied
        default:
            .unexpectedStatus(status)
        }
    }

    private static func readKeychainData(
        serviceName: String,
        promptPolicy: KeychainPromptPolicy
    ) -> Result<Data, ClaudeCredentialError> {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            searchQuery(serviceName: serviceName, promptPolicy: promptPolicy) as CFDictionary,
            &item
        )
        if status == errSecSuccess, let data = item as? Data {
            return .success(data)
        }
        return .failure(error(for: status))
    }

    private struct Wrapper: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresAt: Double?
            let scopes: [String]?
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth
    }

    static func parse(_ data: Data) throws -> ClaudeOAuthCredential {
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            throw ClaudeCredentialError.malformedData
        }
        let oauth = wrapper.claudeAiOauth
        return ClaudeOAuthCredential(
            accessToken: oauth.accessToken,
            refreshToken: oauth.refreshToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            scopes: Set(oauth.scopes ?? []),
            subscriptionType: oauth.subscriptionType
        )
    }
}
