import SwiftUI

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
        case .general: "square.grid.2x2.fill"
        case .notifications: "bell.fill"
        case .refresh: "arrow.clockwise"
        case .agents: "person.2.fill"
        case .dataPrivacy: "lock.fill"
        case .diagnostics: "waveform.path.ecg"
        }
    }

    var navigationTint: Color {
        switch self {
        case .general: .gray
        case .notifications: .red
        case .refresh: .green
        case .agents: .blue
        case .dataPrivacy: .indigo
        case .diagnostics: .orange
        }
    }
}
