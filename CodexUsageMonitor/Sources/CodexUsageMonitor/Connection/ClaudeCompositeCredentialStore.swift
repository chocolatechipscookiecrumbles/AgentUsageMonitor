import Foundation

/// A credential source that can also be cleared — the self-issued side needs
/// this so a revoked long-lived token can be dropped on a 401/403.
protocol ClaudeSelfIssuedCredentialStoring: ClaudeCredentialProviding {
    func delete() async throws
}

extension ClaudeSelfIssuedCredentialStore: ClaudeSelfIssuedCredentialStoring {}

struct ClaudeCredentialResolution: Sendable {
    let credential: ClaudeOAuthCredential
    /// The method that actually served the credential — not necessarily the
    /// selected one, if a degrade happened.
    let method: ClaudeSignInMethod
}

/// Resolves tier 1 exclusively from the user's selected method. A failure
/// degrades to passive data/cache and explicit recovery; it never turns into
/// an undisclosed cross-app Keychain read of the other method.
actor ClaudeCompositeCredentialStore: ClaudeCredentialProviding {
    private var selectedMethod: ClaudeSignInMethod?
    private let selfIssued: ClaudeSelfIssuedCredentialStoring
    private let borrowed: ClaudeCredentialProviding

    init(
        selectedMethod: ClaudeSignInMethod? = nil,
        selfIssued: ClaudeSelfIssuedCredentialStoring = ClaudeSelfIssuedCredentialStore(),
        borrowed: ClaudeCredentialProviding = ClaudeKeychainCredentialStore()
    ) {
        self.selectedMethod = selectedMethod
        self.selfIssued = selfIssued
        self.borrowed = borrowed
    }

    func select(_ method: ClaudeSignInMethod) {
        selectedMethod = method
    }

    func clearSelection() {
        selectedMethod = nil
    }

    func selectedMethodValue() -> ClaudeSignInMethod? {
        selectedMethod
    }

    func resolveCredential(promptPolicy: KeychainPromptPolicy = .never) async throws -> ClaudeCredentialResolution {
        guard let selectedMethod else {
            throw ClaudeCredentialError.notFound
        }
        return try await provider(for: selectedMethod).resolveCredential(promptPolicy: promptPolicy)
    }

    /// Drops a revoked/expired self-issued token so the UI can require an
    /// explicit reconnect without consulting Claude Code's credential.
    func invalidateSelfIssued() async throws {
        try await selfIssued.delete()
    }

    func deleteSelfIssued() async throws {
        try await selfIssued.delete()
    }

    private func provider(for method: ClaudeSignInMethod) -> ClaudeCredentialProviding {
        switch method {
        case .setupToken: selfIssued
        case .claudeCodeCredentials: borrowed
        }
    }
}
