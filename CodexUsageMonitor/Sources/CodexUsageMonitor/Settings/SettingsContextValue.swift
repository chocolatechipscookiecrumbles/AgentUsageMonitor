import Foundation

struct SettingsContextValue: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}
