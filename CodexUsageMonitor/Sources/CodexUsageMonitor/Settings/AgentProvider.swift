import SwiftUI

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

    var tabTitle: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude"
        case .githubCopilot: "Copilot"
        }
    }

    var settingsAssetName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude"
        case .githubCopilot: "Copilot"
        }
    }

    var systemImage: String {
        switch self {
        case .codex: "sparkles"
        case .claudeCode: "terminal"
        case .githubCopilot: "chevron.left.forwardslash.chevron.right"
        }
    }

    var settingsPresentationTint: Color {
        switch self {
        case .codex: Color(red: 87 / 255, green: 109 / 255, blue: 1)
        case .claudeCode: .orange
        case .githubCopilot: .secondary
        }
    }

    func sidebarStatus(connectionState: AgentConnectionState) -> String {
        switch self {
        case .codex: connectionState.displayName
        case .claudeCode, .githubCopilot: "Planned"
        }
    }
}
