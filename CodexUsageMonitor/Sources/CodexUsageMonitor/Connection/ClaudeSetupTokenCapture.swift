import Darwin
import Foundation

protocol ClaudeSetupTokenCapturing: Sendable {
    func captureToken() async throws -> String
}

/// Runs Anthropic's interactive setup-token command in a pseudo-terminal.
/// Output stays in a small memory buffer and is reduced to the token before
/// crossing this boundary; raw terminal output is never logged or persisted.
actor ClaudeSetupTokenCapture: ClaudeSetupTokenCapturing {
    private let locateExecutable: @Sendable () throws -> URL
    private let timeout: Duration

    init(
        locator: ClaudeExecutableLocator = ClaudeExecutableLocator(),
        timeout: Duration = .seconds(300)
    ) {
        self.locateExecutable = { try locator.locate() }
        self.timeout = timeout
    }

    func captureToken() async throws -> String {
        let executable = try locateExecutable()
        let session = ClaudeSetupTokenProcessSession(executable: executable)

        do {
            return try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask { try session.run() }
                    group.addTask {
                        try await Task.sleep(for: self.timeout)
                        throw ClaudeSetupTokenError.timedOut
                    }

                    defer {
                        group.cancelAll()
                        session.cancel()
                    }
                    guard let result = try await group.next() else {
                        throw ClaudeSetupTokenError.setupTokenFailed
                    }
                    return result
                }
            } onCancel: {
                session.cancel()
            }
        } catch is CancellationError {
            throw ClaudeSetupTokenError.cancelled
        } catch {
            if Task.isCancelled { throw ClaudeSetupTokenError.cancelled }
            throw error
        }
    }
}

private final class ClaudeSetupTokenProcessSession: @unchecked Sendable {
    private static let maximumOutputBytes = 8_192

    private let executable: URL
    private let lock = NSLock()
    private var process: Process?
    private var masterHandle: FileHandle?

    init(executable: URL) {
        self.executable = executable
    }

    func run() throws -> String {
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw ClaudeSetupTokenError.setupTokenFailed
        }

        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        let process = Process()
        process.executableURL = executable
        process.arguments = ["setup-token"]
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        lock.withLock {
            self.process = process
            self.masterHandle = masterHandle
        }

        defer {
            lock.withLock {
                self.process = nil
                self.masterHandle = nil
            }
            try? masterHandle.close()
            try? slaveHandle.close()
        }

        do {
            try process.run()
        } catch {
            throw ClaudeSetupTokenError.missingCLI
        }
        try? slaveHandle.close()

        var outputWindow = Data()
        var capturedToken: String?
        while true {
            let chunk: Data
            do {
                chunk = try masterHandle.read(upToCount: 512) ?? Data()
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw ClaudeSetupTokenError.setupTokenFailed
            }
            if chunk.isEmpty { break }
            guard capturedToken == nil else { continue }
            outputWindow.append(chunk)
            if outputWindow.count > Self.maximumOutputBytes {
                outputWindow = Data(outputWindow.suffix(Self.maximumOutputBytes))
            }
            if let text = String(data: outputWindow, encoding: .utf8),
               let token = ClaudeSetupTokenService.extractToken(from: text),
               let range = text.range(of: token), range.upperBound < text.endIndex {
                capturedToken = token
                outputWindow.removeAll(keepingCapacity: false)
            }
        }
        process.waitUntilExit()

        guard !Task.isCancelled else { throw CancellationError() }
        guard process.terminationStatus == 0 else {
            throw ClaudeSetupTokenError.setupTokenFailed
        }
        if let capturedToken {
            return capturedToken
        }
        guard let text = String(data: outputWindow, encoding: .utf8),
              let token = ClaudeSetupTokenService.extractToken(from: text) else {
            throw ClaudeSetupTokenError.tokenNotFoundInOutput
        }
        return token
    }

    func cancel() {
        let active = lock.withLock { (process, masterHandle) }
        if active.0?.isRunning == true {
            active.0?.terminate()
        }
        try? active.1?.close()
    }
}
