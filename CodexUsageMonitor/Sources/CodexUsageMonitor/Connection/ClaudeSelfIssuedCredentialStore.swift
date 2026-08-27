import Foundation
import Security

/// Stores a credential this app obtained through `claude setup-token` in
/// **our own** Keychain item. Because our app
/// creates this item, our later reads never raise the cross-app ACL prompt
/// that reading Claude Code's own item does.
///
/// Persisted in the same JSON shape Claude Code uses so
/// `ClaudeKeychainCredentialStore.parse` is the single decoder for both
/// methods — one parser, one set of edge cases.
actor ClaudeSelfIssuedCredentialStore: ClaudeCredentialProviding {
    static let defaultService = "AgentUsageMonitor-ClaudeOAuth"
    static let defaultAccount = "setup-token-v1"

    private let rawDataReader: @Sendable () -> Result<Data, ClaudeCredentialError>
    private let rawDataWriter: @Sendable (Data) -> Result<Void, ClaudeCredentialError>
    private let rawDeleter: @Sendable () -> Result<Void, ClaudeCredentialError>

    init(
        serviceName: String = defaultService,
        account: String = defaultAccount
    ) {
        self.rawDataReader = { Self.readOrMigrateKeychainData(serviceName: serviceName, account: account) }
        self.rawDataWriter = { Self.writeKeychainData($0, serviceName: serviceName, account: account) }
        self.rawDeleter = { Self.deleteKeychainData(serviceName: serviceName, account: account) }
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain. `environmentReader` defaults to returning nothing so a
    /// variable set on the test machine can never change an outcome.
    init(
        rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>,
        rawDataWriter: @escaping @Sendable (Data) -> Result<Void, ClaudeCredentialError>,
        rawDeleter: @escaping @Sendable () -> Result<Void, ClaudeCredentialError>
    ) {
        self.rawDataReader = rawDataReader
        self.rawDataWriter = rawDataWriter
        self.rawDeleter = rawDeleter
    }

    /// `promptPolicy` is accepted for protocol conformance but has no effect:
    /// this item belongs to us, so reading it never raises an ACL dialog.
    func resolveCredential(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeCredentialResolution {
        switch rawDataReader() {
        case .success(let data):
            return ClaudeCredentialResolution(
                credential: try ClaudeKeychainCredentialStore.parse(data),
                method: .setupToken
            )
        case .failure(let error):
            throw error
        }
    }

    func save(_ credential: ClaudeOAuthCredential) throws {
        let data = try Self.encode(credential)
        try rawDataWriter(data).get()
    }

    func delete() throws {
        try rawDeleter().get()
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
    static func addQuery(service: String, account: String, data: Data) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private static func baseQuery(serviceName: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private static func readKeychainData(serviceName: String, account: String) -> Result<Data, ClaudeCredentialError> {
        var query = baseQuery(serviceName: serviceName, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return .success(data)
        }
        return .failure(ClaudeKeychainCredentialStore.error(for: status))
    }

    private static func writeKeychainData(
        _ data: Data,
        serviceName: String,
        account: String
    ) -> Result<Void, ClaudeCredentialError> {
        let updateStatus = SecItemUpdate(
            baseQuery(serviceName: serviceName, account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return .success(())
        }
        guard updateStatus == errSecItemNotFound else {
            return .failure(ClaudeKeychainCredentialStore.error(for: updateStatus))
        }

        let addStatus = SecItemAdd(
            addQuery(service: serviceName, account: account, data: data) as CFDictionary,
            nil
        )
        if addStatus == errSecSuccess {
            return .success(())
        }
        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(
                baseQuery(serviceName: serviceName, account: account) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            return retryStatus == errSecSuccess
                ? .success(())
                : .failure(ClaudeKeychainCredentialStore.error(for: retryStatus))
        }
        return .failure(ClaudeKeychainCredentialStore.error(for: addStatus))
    }

    private static func deleteKeychainData(
        serviceName: String,
        account: String
    ) -> Result<Void, ClaudeCredentialError> {
        let status = SecItemDelete(
            baseQuery(serviceName: serviceName, account: account) as CFDictionary
        )
        if status == errSecSuccess || status == errSecItemNotFound {
            return .success(())
        }
        return .failure(ClaudeKeychainCredentialStore.error(for: status))
    }

    /// Migrates the service-only item used by pre-release builds. The legacy
    /// item is deleted only after the scoped replacement has round-tripped.
    private static func readOrMigrateKeychainData(
        serviceName: String,
        account: String
    ) -> Result<Data, ClaudeCredentialError> {
        let current = readKeychainData(serviceName: serviceName, account: account)
        guard case .failure(.notFound) = current else { return current }

        var legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &item)
        guard legacyStatus == errSecSuccess, let legacyData = item as? Data else {
            return .failure(ClaudeKeychainCredentialStore.error(for: legacyStatus))
        }
        guard (try? ClaudeKeychainCredentialStore.parse(legacyData)) != nil else {
            return .failure(.malformedData)
        }

        switch writeKeychainData(legacyData, serviceName: serviceName, account: account) {
        case .failure(let error):
            return .failure(error)
        case .success:
            guard case .success(let verified) = readKeychainData(serviceName: serviceName, account: account),
                  verified == legacyData else {
                return .failure(.malformedData)
            }
            legacyQuery.removeValue(forKey: kSecReturnData as String)
            legacyQuery.removeValue(forKey: kSecMatchLimit as String)
            let deleteStatus = SecItemDelete(legacyQuery as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                return .failure(ClaudeKeychainCredentialStore.error(for: deleteStatus))
            }
            return .success(verified)
        }
    }
}
