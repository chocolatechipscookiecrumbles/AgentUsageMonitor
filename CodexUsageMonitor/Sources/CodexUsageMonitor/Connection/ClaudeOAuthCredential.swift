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

protocol ClaudeCredentialProviding: Sendable {
    func loadCredential() throws -> ClaudeOAuthCredential
}

/// Reads Claude Code's own already-issued OAuth credential from the login
/// Keychain (service "Claude Code-credentials"). This app never runs its
/// own sign-in flow and never stores the token anywhere else.
struct ClaudeKeychainCredentialStore: ClaudeCredentialProviding {
    private let rawDataReader: @Sendable () -> Result<Data, ClaudeCredentialError>

    init(serviceName: String = "Claude Code-credentials") {
        self.rawDataReader = { Self.readKeychainData(serviceName: serviceName) }
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain.
    init(rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>) {
        self.rawDataReader = rawDataReader
    }

    func loadCredential() throws -> ClaudeOAuthCredential {
        switch rawDataReader() {
        case .success(let data):
            return try Self.parse(data)
        case .failure(let error):
            throw error
        }
    }

    private static func readKeychainData(serviceName: String) -> Result<Data, ClaudeCredentialError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
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
