import Foundation

enum ClaudeSetupTokenError: Error, Equatable {
    case missingCLI
    case setupTokenFailed
    case tokenNotFoundInOutput
    case timedOut
    case cancelled
    /// The endpoint refused the token (401/403) — it is never persisted.
    case rejected
    case usageUnavailable
}

/// Locates the `claude` CLI, mirroring CodexExecutableLocator's candidate
/// strategy (explicit override → common install prefixes → PATH).
struct ClaudeExecutableLocator {
    private let environment: [String: String]
    private let isExecutable: @Sendable (String) -> Bool

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.environment = environment
        self.isExecutable = isExecutable
    }

    func locate() throws -> URL {
        var candidates: [String] = []
        if let explicit = environment["CLAUDE_EXECUTABLE"], !explicit.isEmpty {
            candidates.append(explicit)
        }
        // Explicit candidates matter because a GUI .app does not inherit the
        // login shell's PATH — it gets a minimal /usr/bin:/bin:/usr/sbin:/sbin.
        // ~/.local/bin is where the official claude.ai/install.sh lands.
        candidates.append(contentsOf: [
            NSHomeDirectory() + "/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
            NSHomeDirectory() + "/.claude/local/claude",
        ])
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(String(directory) + "/claude")
        }
        guard let found = candidates.first(where: isExecutable) else {
            throw ClaudeSetupTokenError.missingCLI
        }
        return URL(fileURLWithPath: found)
    }
}

/// Method (a) of the two user-facing credential methods: obtain a long-lived
/// token by delegating the browser OAuth flow to Anthropic's own
/// `claude setup-token`, then store it in our own Keychain item.
///
/// Because the CLI performs the token exchange, this app never calls
/// `/v1/oauth/token` (so it is never exposed to that endpoint's IP rate
/// limiting) and never raises a cross-app Keychain prompt.
actor ClaudeSetupTokenService {
    static let tokenPrefix = "sk-ant-oat01-"

    private let store: ClaudeSelfIssuedCredentialStore
    private let capture: ClaudeSetupTokenCapturing
    private let usageValidator: @Sendable (ClaudeOAuthCredential) async -> Result<ClaudeUsageSnapshot, ClaudeOAuthError>

    init(
        store: ClaudeSelfIssuedCredentialStore = ClaudeSelfIssuedCredentialStore(),
        capture: ClaudeSetupTokenCapturing = ClaudeSetupTokenCapture(),
        usageValidator: (@Sendable (ClaudeOAuthCredential) async -> Result<ClaudeUsageSnapshot, ClaudeOAuthError>)? = nil
    ) {
        self.store = store
        self.capture = capture
        self.usageValidator = usageValidator ?? { credential in
            let source = ClaudeOAuthUsageSource(credentialStore: StaticCredentialProvider(credential: credential))
            do {
                return .success(try await source.fetch())
            } catch let error as ClaudeOAuthError {
                return .failure(error)
            } catch {
                return .failure(.transportError)
            }
        }
    }

    /// Runs the interactive CLI flow, validates the returned token, then saves
    /// it to the app-owned Keychain item.
    func connect() async throws -> ClaudeAccountSummary {
        let token = try await capture.captureToken()
        return try await validateAndStore(token: token)
    }

    /// Validates against the live usage endpoint *before* persisting, so a bad
    /// or revoked token never reaches the Keychain.
    ///
    /// The credential is built claiming `user:profile` because that is what
    /// `setup-token` grants and what ClaudeOAuthUsageSource pre-checks; the
    /// claim is immediately proven or disproven by this real call, and on
    /// failure nothing is stored.
    private func validateAndStore(token: String) async throws -> ClaudeAccountSummary {
        let credential = ClaudeOAuthCredential(
            accessToken: token,
            refreshToken: nil,
            expiresAt: nil,
            scopes: ["user:profile"],
            subscriptionType: nil
        )

        switch await usageValidator(credential) {
        case .success(let snapshot):
            let confirmed = ClaudeOAuthCredential(
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                scopes: ["user:profile"],
                subscriptionType: snapshot.planHint
            )
            try await store.save(confirmed)
            return ClaudeAccountSummary(planType: snapshot.planHint)
        case .failure(let error):
            // Deliberately does not carry the token into the thrown error.
            switch error {
            case .unauthorized, .insufficientScope, .credentialsNotFound:
                throw ClaudeSetupTokenError.rejected
            default:
                throw ClaudeSetupTokenError.usageUnavailable
            }
        }
    }

    /// Scans CLI output for the `sk-ant-oat01-…` token, tolerating banners,
    /// progress lines, quoting and trailing punctuation around it.
    static func extractToken(from output: String) -> String? {
        guard let prefixRange = output.range(of: tokenPrefix) else { return nil }
        var end = prefixRange.upperBound
        while end < output.endIndex, Self.isTokenCharacter(output[end]) {
            end = output.index(after: end)
        }
        let token = String(output[prefixRange.lowerBound..<end])
        return token.count > tokenPrefix.count ? token : nil
    }

    private static func isTokenCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII
                && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_")
        }
    }

}

/// Wraps an already-obtained credential so it can flow through the existing
/// ClaudeOAuthUsageSource seam during validation.
private struct StaticCredentialProvider: ClaudeCredentialProviding {
    let credential: ClaudeOAuthCredential

    /// Already in hand — no Keychain involved, so the policy is irrelevant.
    func resolveCredential(promptPolicy: KeychainPromptPolicy = .never) async throws -> ClaudeCredentialResolution {
        ClaudeCredentialResolution(credential: credential, method: .setupToken)
    }
}
