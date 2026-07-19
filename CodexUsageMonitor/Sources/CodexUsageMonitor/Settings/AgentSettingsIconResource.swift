import AppKit

enum AgentSettingsIconResource {
    static func fileName(for provider: AgentProvider) -> String {
        switch provider {
        case .codex:
            "codex-agent.png"
        case .claudeCode:
            "claude-code-agent.png"
        case .githubCopilot:
            ""
        }
    }

    static func image(for provider: AgentProvider, bundle: Bundle = .main) -> NSImage? {
        let fileName = fileName(for: provider)
        guard !fileName.isEmpty else { return nil }

        let fileURL = bundle.resourceURL?.appending(path: fileName)
        return fileURL.flatMap(NSImage.init(contentsOf:))
    }
}
