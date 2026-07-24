import AppKit
import Combine
import Foundation

private final class ActivationObserver {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter,
        notification: Notification.Name,
        onActivation: @escaping @Sendable () -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: notification,
            object: nil,
            queue: .main
        ) { _ in
            onActivation()
        }
    }

    func cancel() {
        guard let token else { return }
        notificationCenter.removeObserver(token)
        self.token = nil
    }

    deinit {
        cancel()
    }
}

@MainActor
final class CodexConnectionController: ObservableObject {
    @Published private(set) var state: AgentConnectionState = .checking

    private let service: CodexConnectionService
    private let onConnected: @MainActor () -> Void
    private let statusReader: @Sendable () async -> AgentConnectionState
    private let notificationCenter: NotificationCenter
    private let activationNotification: Notification.Name
    private let disconnectedCheckInterval: Duration
    /// Persisted app-local disconnect flag. While set, the controller stays
    /// disconnected and never auto-detects the still-valid CLI credential.
    private let isUserDisconnected: @MainActor () -> Bool
    private let setUserDisconnected: @MainActor (Bool) -> Void
    private var connectionTask: Task<Void, Never>?
    private var disconnectedWatchTask: Task<Void, Never>?
    private var activationObserver: ActivationObserver?

    init(
        service: CodexConnectionService = CodexConnectionService(),
        onConnected: @escaping @MainActor () -> Void,
        statusReader: (@Sendable () async -> AgentConnectionState)? = nil,
        notificationCenter: NotificationCenter = .default,
        activationNotification: Notification.Name? = nil,
        disconnectedCheckInterval: Duration = .seconds(30),
        isUserDisconnected: @escaping @MainActor () -> Bool = { false },
        setUserDisconnected: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        let activationNotification = activationNotification ?? NSApplication.didBecomeActiveNotification
        self.service = service
        self.onConnected = onConnected
        self.statusReader = statusReader ?? { [service] in await service.readStatus() }
        self.notificationCenter = notificationCenter
        self.activationNotification = activationNotification
        self.disconnectedCheckInterval = disconnectedCheckInterval
        self.isUserDisconnected = isUserDisconnected
        self.setUserDisconnected = setUserDisconnected
    }

    deinit {
        connectionTask?.cancel()
        disconnectedWatchTask?.cancel()
    }

    func start() {
        // Respect a persisted app-local disconnect: stay disconnected without
        // detecting, so the still-valid CLI credential does not auto-reconnect.
        guard !isUserDisconnected() else {
            state = .disconnected
            return
        }
        detectConnection(trigger: .startup)
    }

    /// App-local disconnect: hide Codex usage and stop auto-detecting, leaving
    /// the Codex CLI session and stored credential untouched.
    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        stopDisconnectedWatch()
        stopActivationObserver()
        setUserDisconnected(true)
        // Set directly rather than via applyState so the disconnected watcher
        // and activation observer are not restarted (they would auto-reconnect).
        state = .disconnected
    }

    func checkConnection() {
        setUserDisconnected(false)
        detectConnection(trigger: .userInitiated)
    }

    func recheckConnection() {
        detectConnection(trigger: .refreshFailure)
    }

    private func detectConnection(trigger: ConnectionCheckTrigger) {
        guard connectionTask == nil else { return }
        if trigger.showsCheckingState {
            applyState(.checking)
        }
        let statusReader = statusReader
        connectionTask = Task { [weak self, statusReader] in
            let detectedState = await statusReader()
            guard let self, !Task.isCancelled else { return }
            connectionTask = nil
            applyDetectedState(detectedState, trigger: trigger)
        }
    }

    private func applyDetectedState(
        _ detectedState: AgentConnectionState,
        trigger: ConnectionCheckTrigger
    ) {
        let wasConnected = state.isConnected
        applyState(detectedState)

        if trigger != .startup, !wasConnected, detectedState.isConnected {
            onConnected()
        }
    }

    private func applyState(_ newState: AgentConnectionState) {
        state = newState
        if case .disconnected = newState {
            startDisconnectedWatchIfNeeded()
            startActivationObserverIfNeeded()
        } else {
            stopDisconnectedWatch()
            stopActivationObserver()
        }
    }

    private func startDisconnectedWatchIfNeeded() {
        guard disconnectedWatchTask == nil else { return }
        let interval = disconnectedCheckInterval
        disconnectedWatchTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: interval)
                    guard let self, !Task.isCancelled,
                          case .disconnected = self.state
                    else { return }
                    self.detectConnection(trigger: .disconnectedInterval)
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func stopDisconnectedWatch() {
        disconnectedWatchTask?.cancel()
        disconnectedWatchTask = nil
    }

    private func recheckAfterApplicationActivation() {
        guard case .disconnected = state else { return }
        detectConnection(trigger: .applicationActivation)
    }

    private func startActivationObserverIfNeeded() {
        guard activationObserver == nil else { return }
        activationObserver = ActivationObserver(
            notificationCenter: notificationCenter,
            notification: activationNotification
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.recheckAfterApplicationActivation()
            }
        }
    }

    private func stopActivationObserver() {
        activationObserver?.cancel()
        activationObserver = nil
    }

    func signInWithBrowser() {
        setUserDisconnected(false)
        beginSignIn(using: .browser) { [service] in
            try await service.startBrowserLogin()
        }
    }

    func signInWithCLI() {
        guard connectionTask == nil else { return }
        setUserDisconnected(false)
        applyState(.signingIn(.cli))
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
                applyState(.disconnected)
                connectionTask = nil
            } catch {
                guard let self else { return }
                applyState(mappedFailure(error))
                connectionTask = nil
            }
        }
    }

    private func beginSignIn(
        using method: AgentSignInMethod,
        operation: @escaping @Sendable () async throws -> AgentAccountSummary
    ) {
        guard connectionTask == nil else { return }
        applyState(.signingIn(method))
        connectionTask = Task { [weak self] in
            do {
                let account = try await operation()
                guard let self, !Task.isCancelled else { return }
                completeSignIn(account)
            } catch is CancellationError {
                guard let self else { return }
                applyState(.disconnected)
                connectionTask = nil
            } catch {
                guard let self else { return }
                applyState(mappedFailure(error))
                connectionTask = nil
            }
        }
    }

    private func completeSignIn(_ account: AgentAccountSummary) {
        applyState(.connected(account))
        connectionTask = nil
        onConnected()
    }

    private enum ConnectionCheckTrigger: Equatable {
        case startup
        case userInitiated
        case refreshFailure
        case applicationActivation
        case disconnectedInterval

        var showsCheckingState: Bool {
            self == .startup || self == .userInitiated
        }
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
