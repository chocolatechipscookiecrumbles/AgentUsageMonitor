enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case notifications
    case refresh
    case agents
    case dataPrivacy
    case diagnostics

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .notifications: "Notifications"
        case .refresh: "Refresh"
        case .agents: "Agents"
        case .dataPrivacy: "Data & Privacy"
        case .diagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gear"
        case .notifications: "bell"
        case .refresh: "arrow.clockwise"
        case .agents: "person.3"
        case .dataPrivacy: "hand.raised"
        case .diagnostics: "stethoscope"
        }
    }
}
