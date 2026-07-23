enum AgentSettingsAvailability: Equatable {
    case supported
    case preview
}

struct AgentSettingsCatalogEntry: Identifiable, Equatable {
    let provider: AgentProvider
    let availability: AgentSettingsAvailability

    var id: AgentProvider { provider }
}

enum AgentSettingsCatalog {
    static let entries: [AgentSettingsCatalogEntry] = [
        .init(provider: .codex, availability: .supported),
        .init(provider: .claudeCode, availability: .supported),
    ]
}
