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
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = codexExecutable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        let collector = ResponseCollector()
        output.fileHandleForReading.readabilityHandler = { handle in
            collector.append(handle.availableData)
        }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
            input.fileHandleForWriting.closeFile()
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }

        try process.run()
        try send(CodexProtocol.initializeRequest(), to: input.fileHandleForWriting)
        try waitFor([1], in: collector)

        try send(CodexProtocol.initializedNotification(), to: input.fileHandleForWriting)
        try send(CodexProtocol.accountRequest(), to: input.fileHandleForWriting)
        try send(CodexProtocol.rateLimitsRequest(), to: input.fileHandleForWriting)
        try send(CodexProtocol.usageRequest(), to: input.fileHandleForWriting)
        try waitFor([2, 3, 4], in: collector)

        let responses = collector.responses
        for id in [1, 2, 3, 4] where responses[id]?["error"] != nil {
            throw CodexAppServerError.requestFailed(id)
        }
        return try CodexProtocol.parseSample(responses: responses, collectedAt: .now)
    }

    private func send(_ request: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: request, options: [])
        handle.write(data)
        handle.write(Data([0x0A]))
    }

    private func waitFor(_ identifiers: Set<Int>, in collector: ResponseCollector) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if identifiers.allSatisfy({ collector.responses[$0] != nil }) { return }
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw CodexAppServerError.timedOut
    }
}

private final class ResponseCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffered = Data()
    private var storedResponses: [Int: [String: Any]] = [:]

    var responses: [Int: [String: Any]] {
        lock.withLock { storedResponses }
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock {
            buffered.append(data)
            while let newline = buffered.firstIndex(of: 0x0A) {
                let line = buffered.prefix(upTo: newline)
                buffered.removeSubrange(...newline)
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = message["id"] as? Int
                else { continue }
                storedResponses[id] = message
            }
        }
    }
}
