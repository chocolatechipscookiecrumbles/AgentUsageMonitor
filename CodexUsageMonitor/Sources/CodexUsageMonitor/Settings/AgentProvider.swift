enum AgentProvider: String, CaseIterable, Identifiable {
    case codex
    case claudeCode
    case githubCopilot

    var id: Self { self }

    var title: String {
        switch self {
        case .codex: "OpenAI Codex"
        case .claudeCode: "Claude Code"
        case .githubCopilot: "GitHub Copilot"
        }
    }

    var systemImage: String {
        switch self {
        case .codex: "sparkles"
        case .claudeCode: "terminal"
        case .githubCopilot: "chevron.left.forwardslash.chevron.right"
        }
    }

    func sidebarStatus(connectionState: AgentConnectionState) -> String {
        switch self {
        case .codex: connectionState.displayName
        case .claudeCode, .githubCopilot: "Planned"
        }
    }
}
