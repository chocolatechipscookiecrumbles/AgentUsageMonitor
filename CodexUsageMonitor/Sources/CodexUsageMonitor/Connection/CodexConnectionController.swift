import AppKit
import Combine
import Foundation

@MainActor
final class CodexConnectionController: ObservableObject {
    @Published private(set) var state: AgentConnectionState = .checking

    private let service: CodexConnectionService
    private let onConnected: @MainActor () -> Void
    private var connectionTask: Task<Void, Never>?

    init(
        service: CodexConnectionService = CodexConnectionService(),
        onConnected: @escaping @MainActor () -> Void
    ) {
        self.service = service
        self.onConnected = onConnected
    }

    deinit {
        connectionTask?.cancel()
    }

    func start() {
        checkConnection()
    }

    func checkConnection() {
        detectConnection(showCheckingState: true)
    }

    func recheckConnection() {
        detectConnection(showCheckingState: false)
    }

    private func detectConnection(showCheckingState: Bool) {
        guard connectionTask == nil else { return }
        if showCheckingState {
            state = .checking
        }
        let service = service
        connectionTask = Task { [weak self, service] in
            let detectedState = await service.readStatus()
            guard let self, !Task.isCancelled else { return }
            state = detectedState
            connectionTask = nil
        }
    }

    func signInWithBrowser() {
        beginSignIn(using: .browser) { [service] in
            try await service.startBrowserLogin()
        }
    }

    func signInWithCLI() {
        guard connectionTask == nil else { return }
        state = .signingIn(.cli)
        let service = service
        connectionTask = Task { [weak self, service] in
            do {
                let executable = try await service.locateExecutable()
                try Self.openTerminalForCodexLogin(executable: executable)
                let account = try await service.waitForCLILogin()
                guard let self, !Task.isCancelled else { return }
                completeSignIn(account)
            } catch is CancellationError {
                guard let self else { return }
                state = .disconnected
                connectionTask = nil
            } catch {
                guard let self else { return }
                state = mappedFailure(error)
                connectionTask = nil
            }
        }
    }

    private func beginSignIn(
        using method: AgentSignInMethod,
        operation: @escaping @Sendable () async throws -> AgentAccountSummary
    ) {
        guard connectionTask == nil else { return }
        state = .signingIn(method)
        connectionTask = Task { [weak self] in
            do {
                let account = try await operation()
                guard let self, !Task.isCancelled else { return }
                completeSignIn(account)
            } catch is CancellationError {
                guard let self else { return }
                state = .disconnected
                connectionTask = nil
            } catch {
                guard let self else { return }
                state = mappedFailure(error)
                connectionTask = nil
            }
        }
    }

    private func completeSignIn(_ account: AgentAccountSummary) {
        state = .connected(account)
        connectionTask = nil
        onConnected()
    }

    private func mappedFailure(_ error: Error) -> AgentConnectionState {
        guard let serviceError = error as? CodexConnectionServiceError else {
            return .failed(.appServerUnavailable)
        }
        switch serviceError {
        case .executableNotFound:
            return .missingCLI
        case .browserCouldNotOpen:
            return .failed(.browserCouldNotOpen)
        case .signInFailed:
            return .failed(.signInFailed)
        case .timedOut:
            return .failed(.signInTimedOut)
        case .terminalCouldNotOpen:
            return .failed(.cliCouldNotOpen)
        case .cliTimedOut:
            return .failed(.cliSignInTimedOut)
        case .unavailable:
            return .failed(.appServerUnavailable)
        }
    }

    private static func openTerminalForCodexLogin(executable: URL) throws {
        let codexCommand = "\(shellQuote(executable.path)) login"
        let command: String
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"], !codexHome.isEmpty {
            command = "/usr/bin/env CODEX_HOME=\(shellQuote(codexHome)) \(codexCommand)"
        } else {
            command = codexCommand
        }
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            throw CodexConnectionServiceError.terminalCouldNotOpen
        }
        var details: NSDictionary?
        script.executeAndReturnError(&details)
        if details != nil {
            throw CodexConnectionServiceError.terminalCouldNotOpen
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
