import Foundation

/// A credential source that can also be cleared — the self-issued side needs
/// this so a revoked long-lived token can be dropped on a 401/403.
protocol ClaudeSelfIssuedCredentialStoring: ClaudeCredentialProviding {
    func delete()
}

extension ClaudeSelfIssuedCredentialStore: ClaudeSelfIssuedCredentialStoring {}

struct ClaudeCredentialResolution {
    let credential: ClaudeOAuthCredential
    /// The method that actually served the credential — not necessarily the
    /// selected one, if a degrade happened.
    let method: ClaudeSignInMethod
}

/// Lets the UI and probe see which method actually served the last read,
/// since `ClaudeCredentialProviding.loadCredential()` can only return a
/// credential. A degrade must always be visible, never silently masked.
final class ClaudeEffectiveMethodRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: ClaudeSignInMethod?

    init() {}

    var effectiveMethod: ClaudeSignInMethod? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// Resolves tier 1's credential from the user's **selected** method first,
/// then the other method as an automatic degrade, so a broken method
/// downgrades rather than dead-ends. If both fail it throws, and
/// `ClaudeUsageCollector` degrades to tier 2 (CLI probe) → 3 (statusLine)
/// → 4 (cache).
struct ClaudeCompositeCredentialStore: ClaudeCredentialProviding {
    private let selectedMethod: ClaudeSignInMethod
    private let selfIssued: ClaudeSelfIssuedCredentialStoring
    private let borrowed: ClaudeCredentialProviding
    private let recorder: ClaudeEffectiveMethodRecorder?

    /// Defaults to `.claudeCodeCredentials`: it is the only method proven to
    /// return authoritative usage. Browser sign-in is shelved pending a
    /// decisive re-test — see the spike findings addendum.
    init(
        selectedMethod: ClaudeSignInMethod = .claudeCodeCredentials,
        selfIssued: ClaudeSelfIssuedCredentialStoring = ClaudeSelfIssuedCredentialStore(),
        borrowed: ClaudeCredentialProviding = ClaudeKeychainCredentialStore(),
        recorder: ClaudeEffectiveMethodRecorder? = nil
    ) {
        self.selectedMethod = selectedMethod
        self.selfIssued = selfIssued
        self.borrowed = borrowed
        self.recorder = recorder
    }

    func loadCredential(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeOAuthCredential {
        try resolve(promptPolicy: promptPolicy).credential
    }

    func resolve(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeCredentialResolution {
        let order: [ClaudeSignInMethod] = selectedMethod == .browser
            ? [.browser, .claudeCodeCredentials]
            : [.claudeCodeCredentials, .browser]

        var selectedError: Error?
        for method in order {
            do {
                let credential = try provider(for: method).loadCredential(promptPolicy: promptPolicy)
                recorder?.effectiveMethod = method
                return ClaudeCredentialResolution(credential: credential, method: method)
            } catch {
                if method == selectedMethod { selectedError = error }
            }
        }
        // Surface the selected method's failure so the message matches what
        // the user actually chose.
        throw selectedError ?? ClaudeCredentialError.notFound
    }

    /// Drops a revoked/expired self-issued token so the next resolve degrades
    /// to the other method and the UI can prompt for re-sign-in.
    func invalidateSelfIssued() {
        selfIssued.delete()
    }

    private func provider(for method: ClaudeSignInMethod) -> ClaudeCredentialProviding {
        switch method {
        case .browser: selfIssued
        case .claudeCodeCredentials: borrowed
        }
    }
}
