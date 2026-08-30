import Combine
import Foundation

/// Owns the one explicit Claude connection attempt. The credential belongs to
/// Claude Code; this controller never creates, stores, refreshes, or deletes it.
@MainActor
final class ClaudeConnectionController: ObservableObject {
    @Published private(set) var state: ClaudeConnectionState = .notConnected

    private let credentialsSignIn: @Sendable () async throws -> ClaudeUsageSnapshot
    private let onConnected: @MainActor (ClaudeUsageSnapshot) -> Void
    private let onConnectionFailed: @MainActor () -> Void
    private var connectionTask: Task<Void, Never>?
    private var connectionAttemptID: UUID?

    init(
        credentialsSignIn: @escaping @Sendable () async throws -> ClaudeUsageSnapshot,
        onConnected: @escaping @MainActor (ClaudeUsageSnapshot) -> Void = { _ in },
        onConnectionFailed: @escaping @MainActor () -> Void = {}
    ) {
        self.credentialsSignIn = credentialsSignIn
        self.onConnected = onConnected
        self.onConnectionFailed = onConnectionFailed
    }

    deinit {
        connectionTask?.cancel()
    }

    /// Reads Claude Code's Keychain credential. This is the one call allowed to
    /// raise the cross-app ACL prompt, so it is reached only from Connect.
    func connect() {
        guard connectionTask == nil else { return }
        let attemptID = UUID()
        connectionAttemptID = attemptID
        state = .connecting
        let credentialsSignIn = self.credentialsSignIn
        connectionTask = Task { [weak self, credentialsSignIn] in
            do {
                let snapshot = try await credentialsSignIn()
                guard let self,
                      !Task.isCancelled,
                      connectionAttemptID == attemptID else { return }
                state = .connected(ClaudeAccountSummary(planType: snapshot.planHint))
                connectionAttemptID = nil
                connectionTask = nil
                onConnected(snapshot)
            } catch is CancellationError {
                guard let self, connectionAttemptID == attemptID else { return }
                state = .notConnected
                connectionAttemptID = nil
                connectionTask = nil
            } catch {
                guard let self, connectionAttemptID == attemptID else { return }
                state = Self.mappedFailure(error)
                connectionAttemptID = nil
                connectionTask = nil
                onConnectionFailed()
            }
        }
    }

    /// Applies credential health learned by the monitor without competing with
    /// the explicit interactive connection task.
    func applyCredentialFailure(_ failure: ClaudeConnectionFailure) {
        guard connectionTask == nil else { return }
        state = .failed(failure)
    }

    /// A live OAuth result proves that the borrowed credential works again.
    func applyLiveOAuthSnapshot(_ snapshot: ClaudeUsageSnapshot) {
        guard connectionTask == nil else { return }
        state = .connected(ClaudeAccountSummary(planType: snapshot.planHint))
    }

    /// App-local only. No provider credential is changed.
    func disconnect() {
        connectionAttemptID = nil
        connectionTask?.cancel()
        connectionTask = nil
        state = .notConnected
    }

    private static func mappedFailure(_ error: Error) -> ClaudeConnectionState {
        if let credentialError = error as? ClaudeCredentialError {
            switch credentialError {
            case .accessDenied, .interactionNotAllowed:
                return .failed(.keychainAccessDenied)
            case .unexpectedStatus:
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
            case .credentialsNotFound, .unauthorized:
                return .failed(.credentialsNotFound)
            case .insufficientScope:
                return .failed(.insufficientUsageScope)
            case .malformedResponse, .serverFailure, .rateLimited, .transportError:
                return .failed(.usageUnavailable)
            }
        }
        return .failed(.usageUnavailable)
    }
}
