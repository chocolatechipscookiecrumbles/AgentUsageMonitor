import Combine
import Foundation

/// Drives the two co-equal Claude credential methods, mirroring
/// CodexConnectionController's shape (shared `beginSignIn`, an in-flight task
/// guard, and typed failure mapping) so both agents behave the same way.
@MainActor
final class ClaudeConnectionController: ObservableObject {
    @Published private(set) var state: ClaudeConnectionState = .notConnected

    private let browserSignIn: @Sendable () async throws -> ClaudeAccountSummary
    private let credentialsSignIn: @Sendable () async throws -> ClaudeAccountSummary
    private let onMethodSelected: @MainActor (ClaudeSignInMethod?) -> Void
    private var connectionTask: Task<Void, Never>?

    init(
        browserSignIn: @escaping @Sendable () async throws -> ClaudeAccountSummary,
        credentialsSignIn: @escaping @Sendable () async throws -> ClaudeAccountSummary,
        onMethodSelected: @escaping @MainActor (ClaudeSignInMethod?) -> Void = { _ in }
    ) {
        self.browserSignIn = browserSignIn
        self.credentialsSignIn = credentialsSignIn
        self.onMethodSelected = onMethodSelected
    }

    deinit {
        connectionTask?.cancel()
    }

    /// Method (a): delegate the browser OAuth flow to `claude setup-token`.
    func signInWithBrowser() {
        beginSignIn(using: .browser, operation: browserSignIn)
    }

    /// Method (b): read Claude Code's existing Keychain credential. This is
    /// the call that may raise the cross-app ACL prompt, which is why it is
    /// only ever reached by an explicit user action.
    func useClaudeCodeCredentials() {
        beginSignIn(using: .claudeCodeCredentials, operation: credentialsSignIn)
    }

    func signOut() {
        connectionTask?.cancel()
        connectionTask = nil
        state = .notConnected
        onMethodSelected(nil)
    }

    private func beginSignIn(
        using method: ClaudeSignInMethod,
        operation: @escaping @Sendable () async throws -> ClaudeAccountSummary
    ) {
        guard connectionTask == nil else { return }
        state = .signingIn(method)
        connectionTask = Task { [weak self] in
            do {
                let account = try await operation()
                guard let self, !Task.isCancelled else { return }
                state = .connected(account)
                connectionTask = nil
                onMethodSelected(method)
            } catch is CancellationError {
                guard let self else { return }
                state = .notConnected
                connectionTask = nil
            } catch {
                guard let self else { return }
                state = Self.mappedFailure(error)
                connectionTask = nil
            }
        }
    }

    private static func mappedFailure(_ error: Error) -> ClaudeConnectionState {
        if let setupError = error as? ClaudeSetupTokenError {
            switch setupError {
            case .missingCLI:
                return .missingCLI
            case .setupTokenFailed, .tokenNotFoundInOutput, .rejected:
                return .failed(.setupTokenFailed)
            case .usageUnavailable:
                return .failed(.usageUnavailable)
            }
        }
        if let credentialError = error as? ClaudeCredentialError {
            switch credentialError {
            case .accessDenied:
                return .failed(.keychainAccessDenied)
            case .notFound, .malformedData:
                return .failed(.credentialsNotFound)
            }
        }
        // The credentials path fetches usage as its proof of connection, so
        // OAuth-layer failures surface here too.
        if let oauthError = error as? ClaudeOAuthError {
            switch oauthError {
            case .credentialAccessDenied:
                // The credential exists; macOS refused this app's read. That is
                // the Keychain recovery path, not the reconnect-from-scratch one.
                return .failed(.keychainAccessDenied)
            case .credentialsNotFound, .unauthorized, .insufficientScope:
                return .failed(.credentialsNotFound)
            case .malformedResponse, .serverFailure, .rateLimited, .transportError:
                return .failed(.usageUnavailable)
            }
        }
        return .failed(.usageUnavailable)
    }
}
