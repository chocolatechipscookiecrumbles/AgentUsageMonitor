import SwiftUI

enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    func presentationColorScheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: system
        case .light: .light
        case .dark: .dark
        }
    }
}
