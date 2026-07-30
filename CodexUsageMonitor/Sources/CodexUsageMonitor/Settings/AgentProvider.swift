import SwiftUI

enum AgentProvider: String, CaseIterable, Identifiable, Sendable, Codable {
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

    /// The menu bar draws its glyph as a template, which paints every
    /// non-transparent pixel with the tint. Codex therefore needs artwork of
    /// its own: its colored mark is a full-bleed opaque square — deliberate in
    /// the settings tiles, a solid block in the menu bar. Claude's and
    /// Copilot's marks are already transparent, so they reuse theirs.
    var menuBarAssetName: String {
        switch self {
        case .codex: "CodexMenuBar"
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
        case .claudeCode: Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
        case .githubCopilot: .secondary
        }
    }
}
