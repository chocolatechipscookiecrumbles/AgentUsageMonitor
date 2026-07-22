import Foundation
import Security

/// Stores a credential this app obtained itself (via `claude setup-token`, or
/// the last-resort PKCE flow) in **our own** Keychain item. Because our app
/// creates this item, our later reads never raise the cross-app ACL prompt
/// that reading Claude Code's own item does.
///
/// Persisted in the same JSON shape Claude Code uses so
/// `ClaudeKeychainCredentialStore.parse` is the single decoder for both
/// methods — one parser, one set of edge cases.
struct ClaudeSelfIssuedCredentialStore: ClaudeCredentialProviding {
    static let defaultService = "AgentUsageMonitor-ClaudeOAuth"

    static let environmentTokenVariable = "CLAUDE_CODE_OAUTH_TOKEN"

    private let rawDataReader: @Sendable () -> Result<Data, ClaudeCredentialError>
    private let rawDataWriter: @Sendable (Data) -> Bool
    private let rawDeleter: @Sendable () -> Void
    private let environmentReader: @Sendable (String) -> String?

    init(
        serviceName: String = defaultService,
        environmentReader: @escaping @Sendable (String) -> String? = { ProcessInfo.processInfo.environment[$0] }
    ) {
        self.rawDataReader = { Self.readKeychainData(serviceName: serviceName) }
        self.rawDataWriter = { Self.writeKeychainData($0, serviceName: serviceName) }
        self.rawDeleter = { Self.deleteKeychainData(serviceName: serviceName) }
        self.environmentReader = environmentReader
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain. `environmentReader` defaults to returning nothing so a
    /// variable set on the test machine can never change an outcome.
    init(
        rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>,
        rawDataWriter: @escaping @Sendable (Data) -> Bool,
        rawDeleter: @escaping @Sendable () -> Void,
        environmentReader: @escaping @Sendable (String) -> String? = { _ in nil }
    ) {
        self.rawDataReader = rawDataReader
        self.rawDataWriter = rawDataWriter
        self.rawDeleter = rawDeleter
        self.environmentReader = environmentReader
    }

    /// Resolution order: `CLAUDE_CODE_OAUTH_TOKEN` → our own Keychain item.
    /// The environment variable is honoured at *read* time (not only during
    /// sign-in) so a `claude setup-token` value can drive the app on machines
    /// where the CLI isn't installed, matching how comparable tools resolve
    /// credentials.
    /// `promptPolicy` is accepted for protocol conformance but has no effect:
    /// this item belongs to us, so reading it never raises an ACL dialog.
    func loadCredential(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeOAuthCredential {
        if let token = environmentReader(Self.environmentTokenVariable)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty {
            // Claims user:profile because that is what setup-token grants and
            // what ClaudeOAuthUsageSource pre-checks; the server immediately
            // proves or disproves it on the very next call.
            return ClaudeOAuthCredential(
                accessToken: token, refreshToken: nil, expiresAt: nil,
                scopes: ["user:profile"], subscriptionType: nil
            )
        }
        switch rawDataReader() {
        case .success(let data):
            return try ClaudeKeychainCredentialStore.parse(data)
        case .failure(let error):
            throw error
        }
    }

    func save(_ credential: ClaudeOAuthCredential) throws {
        let data = try Self.encode(credential)
        guard rawDataWriter(data) else { throw ClaudeCredentialError.accessDenied }
    }

    func delete() {
        rawDeleter()
    }

    /// Encodes to Claude Code's own wrapper shape (`expiresAt` in Unix
    /// milliseconds) so the shared parser round-trips it exactly.
    static func encode(_ credential: ClaudeOAuthCredential) throws -> Data {
        var oauth: [String: Any] = ["accessToken": credential.accessToken]
        if let refreshToken = credential.refreshToken {
            oauth["refreshToken"] = refreshToken
        }
        if let expiresAt = credential.expiresAt {
            oauth["expiresAt"] = expiresAt.timeIntervalSince1970 * 1000
        }
        if !credential.scopes.isEmpty {
            oauth["scopes"] = credential.scopes.sorted()
        }
        if let subscriptionType = credential.subscriptionType {
            oauth["subscriptionType"] = subscriptionType
        }
        return try JSONSerialization.data(withJSONObject: ["claudeAiOauth": oauth])
    }

    /// The attributes our item is created with. Device-only, never
    /// iCloud-synchronizable — the token is a long-lived, password-equivalent
    /// credential and must not leave this machine.
    static func addQuery(service: String, data: Data) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
    }

    private static func baseQuery(serviceName: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]
    }

    private static func readKeychainData(serviceName: String) -> Result<Data, ClaudeCredentialError> {
        var query = baseQuery(serviceName: serviceName)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return .success(data)
        }
        if status == errSecItemNotFound {
            return .failure(.notFound)
        }
        return .failure(.accessDenied)
    }

    private static func writeKeychainData(_ data: Data, serviceName: String) -> Bool {
        // Replace rather than update-in-place so a re-sign-in always lands on
        // clean attributes.
        deleteKeychainData(serviceName: serviceName)
        let status = SecItemAdd(addQuery(service: serviceName, data: data) as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func deleteKeychainData(serviceName: String) {
        SecItemDelete(baseQuery(serviceName: serviceName) as CFDictionary)
    }
}
