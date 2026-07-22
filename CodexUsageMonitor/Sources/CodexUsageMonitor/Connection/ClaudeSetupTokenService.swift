import Foundation

enum ClaudeSetupTokenError: Error, Equatable {
    case missingCLI
    case setupTokenFailed
    case tokenNotFoundInOutput
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
    private let environmentReader: @Sendable (String) -> String?
    private let setupTokenRunner: @Sendable () throws -> String
    private let usageValidator: @Sendable (ClaudeOAuthCredential) async -> Result<ClaudeUsageSnapshot, ClaudeOAuthError>

    init(
        store: ClaudeSelfIssuedCredentialStore = ClaudeSelfIssuedCredentialStore(),
        environmentReader: @escaping @Sendable (String) -> String? = { ProcessInfo.processInfo.environment[$0] },
        setupTokenRunner: (@Sendable () throws -> String)? = nil,
        usageValidator: (@Sendable (ClaudeOAuthCredential) async -> Result<ClaudeUsageSnapshot, ClaudeOAuthError>)? = nil
    ) {
        self.store = store
        self.environmentReader = environmentReader
        self.setupTokenRunner = setupTokenRunner ?? { try Self.runSetupToken() }
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

    /// Resolves a token from the environment, else by running the CLI.
    func connect() async throws -> ClaudeAccountSummary {
        if let envToken = environmentReader("CLAUDE_CODE_OAUTH_TOKEN")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envToken.isEmpty {
            return try await validateAndStore(token: envToken)
        }
        let output = try setupTokenRunner()
        guard let token = Self.extractToken(from: output) else {
            throw ClaudeSetupTokenError.tokenNotFoundInOutput
        }
        return try await validateAndStore(token: token)
    }

    /// Entry point for the "paste your `claude setup-token` output" affordance,
    /// used when we cannot spawn the CLI ourselves.
    func connect(pastedToken: String) async throws -> ClaudeAccountSummary {
        let trimmed = pastedToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = Self.extractToken(from: trimmed) ?? trimmed
        guard !token.isEmpty else { throw ClaudeSetupTokenError.tokenNotFoundInOutput }
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
            try store.save(confirmed)
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
        for line in output.split(whereSeparator: \.isNewline) {
            for field in line.split(whereSeparator: { $0.isWhitespace }) {
                let candidate = field.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`.,;:()[]{}"))
                if candidate.hasPrefix(tokenPrefix), candidate.count > tokenPrefix.count {
                    return candidate
                }
            }
        }
        return nil
    }

    private static func runSetupToken() throws -> String {
        let executable = try ClaudeExecutableLocator().locate()
        let process = Process()
        process.executableURL = executable
        process.arguments = ["setup-token"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw ClaudeSetupTokenError.missingCLI
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ClaudeSetupTokenError.setupTokenFailed
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Wraps an already-obtained credential so it can flow through the existing
/// ClaudeOAuthUsageSource seam during validation.
private struct StaticCredentialProvider: ClaudeCredentialProviding {
    let credential: ClaudeOAuthCredential

    /// Already in hand — no Keychain involved, so the policy is irrelevant.
    func loadCredential(promptPolicy: KeychainPromptPolicy = .never) throws -> ClaudeOAuthCredential {
        credential
    }
}
