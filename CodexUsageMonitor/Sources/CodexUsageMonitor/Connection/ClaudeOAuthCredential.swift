import Foundation
import Security

/// Deliberately NOT Codable, CustomStringConvertible, or
/// CustomDebugStringConvertible — nothing about this type should be
/// persistable or printable by accident. The token lives in Keychain only.
struct ClaudeOAuthCredential {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: Set<String>
    let subscriptionType: String?
}

enum ClaudeCredentialError: Error, Equatable {
    case notFound
    case malformedData
    case accessDenied
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
    func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential
}

extension ClaudeCredentialProviding {
    /// Defaults to the safe policy so a call site that forgets to specify one
    /// can never introduce a background prompt.
    func loadCredential() throws -> ClaudeOAuthCredential {
        try loadCredential(promptPolicy: .never)
    }
}

/// Reads Claude Code's own already-issued OAuth credential from the login
/// Keychain (service "Claude Code-credentials"). This app never runs its
/// own sign-in flow and never stores the token anywhere else.
struct ClaudeKeychainCredentialStore: ClaudeCredentialProviding {
    private let rawDataReader: @Sendable (KeychainPromptPolicy) -> Result<Data, ClaudeCredentialError>

    init(serviceName: String = "Claude Code-credentials") {
        self.rawDataReader = { Self.readKeychainData(serviceName: serviceName, promptPolicy: $0) }
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain.
    init(rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>) {
        self.rawDataReader = { _ in rawDataReader() }
    }

    func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
        switch rawDataReader(promptPolicy) {
        case .success(let data):
            return try Self.parse(data)
        case .failure(let error):
            throw error
        }
    }

    /// Built separately so the prompt policy is directly assertable — a
    /// background read setting `kSecUseAuthenticationUIFail` is the guarantee
    /// that an automatic refresh cannot pop a dialog.
    static func searchQuery(serviceName: String, promptPolicy: KeychainPromptPolicy) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if promptPolicy == .never {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        return query
    }

    /// `errSecInteractionNotAllowed` is what a `.never` read returns instead
    /// of prompting; it maps to `.accessDenied` so the collector degrades to
    /// the next tier rather than treating it as a hard failure.
    static func error(for status: OSStatus) -> ClaudeCredentialError {
        status == errSecItemNotFound ? .notFound : .accessDenied
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
