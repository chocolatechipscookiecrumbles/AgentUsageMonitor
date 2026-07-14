import AppKit
import Foundation

enum CodexConnectionServiceError: Error {
    case executableNotFound
    case browserCouldNotOpen
    case signInFailed
    case timedOut
    case terminalCouldNotOpen
    case cliTimedOut
    case unavailable
}

actor CodexConnectionService {
    private let locator: CodexExecutableLocator
    private let statusTimeout: TimeInterval
    private let signInTimeout: TimeInterval

    init(
        locator: CodexExecutableLocator = CodexExecutableLocator(),
        statusTimeout: TimeInterval = 15,
        signInTimeout: TimeInterval = 300
    ) {
        self.locator = locator
        self.statusTimeout = statusTimeout
        self.signInTimeout = signInTimeout
    }

    func readStatus() async -> AgentConnectionState {
        do {
            let executable = try locateExecutable()
            if let account = try readAccount(codexExecutable: executable) {
                return .connected(account)
            }
            return .disconnected
        } catch CodexConnectionServiceError.executableNotFound {
            return .missingCLI
        } catch {
            return .failed(.appServerUnavailable)
        }
    }

    func locateExecutable() throws -> URL {
        do {
            return try locator.locate()
        } catch CodexAppServerError.executableNotFound {
            throw CodexConnectionServiceError.executableNotFound
        } catch {
            throw CodexConnectionServiceError.unavailable
        }
    }

    func startBrowserLogin() async throws -> AgentAccountSummary {
        let executable = try locateExecutable()
        let session = CodexAppServerProcess(codexExecutable: executable)
        defer { session.stop() }

        do {
            try session.startInitialized(timeout: statusTimeout)
            try session.send(CodexProtocol.browserLoginRequest())
            try session.waitForResponses([5], timeout: statusTimeout)
            guard let response = session.responses[5] else {
                throw CodexConnectionServiceError.unavailable
            }
            let login = try CodexProtocol.parseBrowserLogin(response: response)
            let opened = await MainActor.run { NSWorkspace.shared.open(login.authURL) }
            guard opened else { throw CodexConnectionServiceError.browserCouldNotOpen }

            let completion = try await session.waitForLoginCompletion(
                loginID: login.loginID,
                timeout: signInTimeout
            )
            guard let params = completion["params"] as? [String: Any],
                  params["success"] as? Bool == true
            else {
                throw CodexConnectionServiceError.signInFailed
            }
        } catch CodexAppServerError.timedOut {
            throw CodexConnectionServiceError.timedOut
        } catch let error as CodexConnectionServiceError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CodexConnectionServiceError.unavailable
        }

        return try await confirmConnectedAccount(codexExecutable: executable)
    }

    func waitForCLILogin() async throws -> AgentAccountSummary {
        let executable = try locateExecutable()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(signInTimeout))
        while clock.now < deadline {
            try Task.checkCancellation()
            if runLoginStatus(codexExecutable: executable),
               let account = try? readAccount(codexExecutable: executable) {
                return account
            }
            try await Task.sleep(for: .seconds(2))
        }
        throw CodexConnectionServiceError.cliTimedOut
    }

    private func confirmConnectedAccount(codexExecutable: URL) async throws -> AgentAccountSummary {
        for _ in 0..<10 {
            try Task.checkCancellation()
            if let account = try? readAccount(codexExecutable: codexExecutable) {
                return account
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw CodexConnectionServiceError.signInFailed
    }

    private func readAccount(codexExecutable: URL) throws -> AgentAccountSummary? {
        let session = CodexAppServerProcess(codexExecutable: codexExecutable)
        defer { session.stop() }
        try session.startInitialized(timeout: statusTimeout)
        try session.send(CodexProtocol.accountRequest())
        try session.waitForResponses([2], timeout: statusTimeout)
        guard let response = session.responses[2] else {
            throw CodexConnectionServiceError.unavailable
        }
        return try CodexProtocol.parseAccountSummary(response: response)
    }

    private func runLoginStatus(codexExecutable: URL) -> Bool {
        let process = Process()
        process.executableURL = codexExecutable
        process.arguments = ["login", "status"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(statusTimeout)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                CodexProcessLifecycle.stop(process)
                return false
            }
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
