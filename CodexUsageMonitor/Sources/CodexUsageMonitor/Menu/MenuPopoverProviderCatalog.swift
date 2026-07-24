enum MenuPopoverProviderCatalog {
    static let availableProviders: [AgentProvider] = AgentSettingsCatalog.entries.compactMap { entry in
        entry.availability == .supported ? entry.provider : nil
    }

    static func resolvedSelection(_ requestedProvider: AgentProvider?) -> AgentProvider {
        if let requestedProvider, availableProviders.contains(requestedProvider) {
            return requestedProvider
        }
        if availableProviders.contains(.codex) {
            return .codex
        }
        return availableProviders.first ?? .codex
    }
}
