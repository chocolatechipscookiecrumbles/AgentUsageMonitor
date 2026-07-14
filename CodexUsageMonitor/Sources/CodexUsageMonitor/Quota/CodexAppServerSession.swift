import Foundation

enum CodexAppServerError: LocalizedError {
    case executableNotFound
    case timedOut
    case requestFailed(Int)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Could not locate the Codex CLI. Sign in to Codex, then set CODEX_EXECUTABLE if it is installed outside a standard location."
        case .timedOut:
            "Codex app-server did not return the required account data within 15 seconds."
        case .requestFailed(let id):
            "Codex app-server rejected the read-only request \(id)."
        case .processFailed(let detail):
            "Codex app-server failed: \(detail)"
        }
    }
}

final class CodexExecutableLocator {
    func locate() throws -> URL {
        let manager = FileManager.default
        let environment = ProcessInfo.processInfo.environment
        var candidates: [URL] = []
        if let explicit = environment["CODEX_EXECUTABLE"], !explicit.isEmpty {
            candidates.append(URL(fileURLWithPath: explicit))
        }
        for path in ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/usr/bin/codex"] {
            candidates.append(URL(fileURLWithPath: path))
        }
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("codex"))
        }
        let extensions = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".vscode/extensions")
        if let contents = try? manager.contentsOfDirectory(at: extensions, includingPropertiesForKeys: nil) {
            for extensionURL in contents where extensionURL.lastPathComponent.hasPrefix("openai.chatgpt-") {
                candidates.append(extensionURL.appendingPathComponent("bin/macos-aarch64/codex"))
                candidates.append(extensionURL.appendingPathComponent("bin/macos-x86_64/codex"))
            }
        }
        if let executable = candidates.first(where: { manager.isExecutableFile(atPath: $0.path) }) {
            return executable
        }
        throw CodexAppServerError.executableNotFound
    }
}

final class CodexAppServerSession {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 15) {
        self.timeout = timeout
    }

    func collectSample(codexExecutable: URL) throws -> CodexQuotaSample {
        let connection = CodexAppServerProcess(codexExecutable: codexExecutable)
        defer { connection.stop() }
        try connection.startInitialized(timeout: timeout)
        try connection.send(CodexProtocol.accountRequest())
        try connection.send(CodexProtocol.rateLimitsRequest())
        try connection.send(CodexProtocol.usageRequest())
        try connection.waitForResponses([2, 3, 4], timeout: timeout)

        let responses = connection.responses
        for id in [1, 2, 3, 4] where responses[id]?["error"] != nil {
            throw CodexAppServerError.requestFailed(id)
        }
        return try CodexProtocol.parseSample(responses: responses, collectedAt: .now)
    }
}

final class CodexAppServerProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let collector = CodexMessageCollector()
    private var hasStarted = false
    private var hasStopped = false

    init(codexExecutable: URL) {
        process.executableURL = codexExecutable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    var responses: [Int: [String: Any]] { collector.responses }

    func startInitialized(timeout: TimeInterval) throws {
        output.fileHandleForReading.readabilityHandler = { [collector] handle in
            collector.append(handle.availableData)
        }
        try process.run()
        hasStarted = true
        try send(CodexProtocol.initializeRequest())
        try waitForResponses([1], timeout: timeout)
        guard responses[1]?["error"] == nil else {
            throw CodexAppServerError.requestFailed(1)
        }
        try send(CodexProtocol.initializedNotification())
    }

    func send(_ request: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: request, options: [])
        input.fileHandleForWriting.write(data)
        input.fileHandleForWriting.write(Data([0x0A]))
    }

    func waitForResponses(_ identifiers: Set<Int>, timeout: TimeInterval) throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        while clock.now < deadline {
            try Task.checkCancellation()
            if identifiers.allSatisfy({ responses[$0] != nil }) { return }
            guard process.isRunning else {
                throw CodexAppServerError.processFailed("the process exited before responding")
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw CodexAppServerError.timedOut
    }

    func waitForLoginCompletion(loginID: String, timeout: TimeInterval) async throws -> [String: Any] {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        while clock.now < deadline {
            try Task.checkCancellation()
            if let message = collector.loginCompletion(loginID: loginID) { return message }
            guard process.isRunning else {
                throw CodexAppServerError.processFailed("the process exited before sign-in completed")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CodexAppServerError.timedOut
    }

    func stop() {
        guard !hasStopped else { return }
        hasStopped = true
        output.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        guard hasStarted else { return }
        CodexProcessLifecycle.stop(process)
    }
}

private final class CodexMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffered = Data()
    private var storedResponses: [Int: [String: Any]] = [:]
    private var storedNotifications: [[String: Any]] = []

    var responses: [Int: [String: Any]] {
        lock.withLock { storedResponses }
    }

    func loginCompletion(loginID: String) -> [String: Any]? {
        lock.withLock {
            storedNotifications.first { message in
                guard message["method"] as? String == "account/login/completed",
                      let params = message["params"] as? [String: Any]
                else { return false }
                return params["loginId"] as? String == loginID
            }
        }
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            buffered.append(data)
            while let newline = buffered.firstIndex(of: 0x0A) {
                let line = buffered.prefix(upTo: newline)
                buffered.removeSubrange(...newline)
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                if let id = message["id"] as? Int {
                    storedResponses[id] = message
                } else if message["method"] is String {
                    storedNotifications.append(message)
                }
            }
        }
    }
}
