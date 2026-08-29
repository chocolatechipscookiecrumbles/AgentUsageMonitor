import Foundation

enum ClaudeExecutableLocatorError: Error {
    case missingCLI
}

/// Locates Claude Code from a GUI process, whose PATH normally omits user and
/// Homebrew install directories.
struct ClaudeExecutableLocator {
    private let environment: [String: String]
    private let isExecutable: @Sendable (String) -> Bool

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: @escaping @Sendable (String) -> Bool = {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    ) {
        self.environment = environment
        self.isExecutable = isExecutable
    }

    func locate() throws -> URL {
        var candidates: [String] = []
        if let explicit = environment["CLAUDE_EXECUTABLE"], !explicit.isEmpty {
            candidates.append(explicit)
        }
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
            throw ClaudeExecutableLocatorError.missingCLI
        }
        return URL(fileURLWithPath: found)
    }
}
