import Foundation
import LocalAuthentication
import Security

/// Deliberately NOT Codable, CustomStringConvertible, or
/// CustomDebugStringConvertible — nothing about this type should be
/// persistable or printable by accident. The token lives in Keychain only.
struct ClaudeOAuthCredential: Sendable {
    let accessToken: String
    let scopes: Set<String>
    let subscriptionType: String?
}

enum ClaudeCredentialError: Error, Equatable, Sendable {
    case notFound
    case malformedData
    case interactionNotAllowed
    case accessDenied
    case userCancelled
    case unexpectedStatus(OSStatus)
}

/// Controls whether a Keychain read may raise macOS's permission dialog.
///
/// Reading Claude Code's own Keychain item from our process is an ACL-gated
/// cross-app access, so it *can* prompt. A prompt is acceptable when the user
/// just pressed Connect/Reconnect; it is never acceptable on an ordinary refresh,
/// which would interrupt them on a timer.
enum KeychainPromptPolicy: Equatable, Sendable {
    /// Fail the read rather than prompt. Used for every automatic refresh.
    case never
    /// Allow macOS to prompt. Only ever reached from an explicit user action.
    case userInitiatedOnly
}

protocol ClaudeCredentialProviding: Sendable {
    func loadCredential(promptPolicy: KeychainPromptPolicy) async throws -> ClaudeOAuthCredential
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

    func loadCredential(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeOAuthCredential {
        switch rawDataReader(promptPolicy) {
        case .success(let data):
            return try Self.parse(data)
        case .failure(let error):
            throw error
        }
    }

    /// Keep a noninteractive context for authentication-aware query paths.
    /// The legacy Keychain path additionally requires the process-level guard below.
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
        case errSecAuthFailed:
            .accessDenied
        case errSecUserCanceled:
            .userCancelled
        default:
            .unexpectedStatus(status)
        }
    }

    private static func readKeychainData(
        serviceName: String,
        promptPolicy: KeychainPromptPolicy
    ) -> Result<Data, ClaudeCredentialError> {
        withLegacyInteractionPolicy(promptPolicy) {
            readScopedKeychainData(serviceName: serviceName, promptPolicy: promptPolicy)
        }
    }

    // Legacy SecItem reads do not honor LAContext's interaction flag. Serialize
    // both policies while temporarily disabling the process-wide legacy UI flag.
    // ponytail: process-wide flag; future legacy Keychain clients must share this lock.
    private static let legacyReadLock = NSLock()

    static func withLegacyInteractionPolicy(
        _ policy: KeychainPromptPolicy,
        getAllowed: (UnsafeMutablePointer<DarwinBoolean>) -> OSStatus = SecKeychainGetUserInteractionAllowed,
        setAllowed: (Bool) -> OSStatus = SecKeychainSetUserInteractionAllowed,
        read: () -> Result<Data, ClaudeCredentialError>
    ) -> Result<Data, ClaudeCredentialError> {
        legacyReadLock.lock()
        defer { legacyReadLock.unlock() }
        guard policy == .never else { return read() }

        var allowed: DarwinBoolean = false
        let getStatus = getAllowed(&allowed)
        guard getStatus == errSecSuccess else { return .failure(.unexpectedStatus(getStatus)) }
        let disableStatus = setAllowed(false)
        let result = disableStatus == errSecSuccess ? read() : .failure(.unexpectedStatus(disableStatus))
        let restoreStatus = setAllowed(allowed.boolValue)
        guard restoreStatus == errSecSuccess else { return .failure(.unexpectedStatus(restoreStatus)) }
        return result
    }

    private static func readScopedKeychainData(
        serviceName: String,
        promptPolicy: KeychainPromptPolicy
    ) -> Result<Data, ClaudeCredentialError> {
        // Claude Code owns a legacy file-based Keychain item. Restrict the
        // query to one default Keychain rather than inheriting the search list.
        var keychain: SecKeychain?
        let keychainStatus = SecKeychainCopyDefault(&keychain)
        guard keychainStatus == errSecSuccess, let keychain else {
            return .failure(error(for: keychainStatus == errSecSuccess ? errSecInternalError : keychainStatus))
        }
        var query = searchQuery(serviceName: serviceName, promptPolicy: promptPolicy)
        query[kSecMatchSearchList as String] = [keychain]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &item
        )
        guard status == errSecSuccess else { return .failure(error(for: status)) }
        guard let data = item as? Data else { return .failure(.malformedData) }
        return .success(data)
    }

    private struct Wrapper: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
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
            scopes: Set(oauth.scopes ?? []),
            subscriptionType: oauth.subscriptionType
        )
    }
}
