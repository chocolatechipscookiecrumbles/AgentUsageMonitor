import SwiftUI

struct SettingsAppearancePalette {
    let windowBackground: Color
    let sidebarBackground: Color
    let pageBackground: Color
    let contextRailBackground: Color
    let sectionSurface: Color
    let divider: Color
    let searchFieldBackground: Color
    let sidebarSelection: Color

    static func resolve(for colorScheme: ColorScheme) -> Self {
        if colorScheme == .dark {
            return Self(
                windowBackground: Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255),
                sidebarBackground: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
                pageBackground: Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255),
                contextRailBackground: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
                sectionSurface: .white.opacity(0.055),
                divider: .white.opacity(0.06),
                searchFieldBackground: .white.opacity(0.08),
                sidebarSelection: .white.opacity(0.10)
            )
        }

        return Self(
            windowBackground: Color(nsColor: .windowBackgroundColor),
            sidebarBackground: Color(nsColor: .windowBackgroundColor),
            pageBackground: Color(nsColor: .windowBackgroundColor),
            contextRailBackground: Color(nsColor: .windowBackgroundColor),
            sectionSurface: Color(nsColor: .controlBackgroundColor),
            divider: Color(nsColor: .separatorColor),
            searchFieldBackground: Color(nsColor: .controlBackgroundColor).opacity(0.7),
            sidebarSelection: Color(nsColor: .controlBackgroundColor)
        )
    }
}

private struct SettingsAppearancePaletteKey: EnvironmentKey {
    static let defaultValue = SettingsAppearancePalette.resolve(for: .light)
}

extension EnvironmentValues {
    var settingsAppearancePalette: SettingsAppearancePalette {
        get { self[SettingsAppearancePaletteKey.self] }
        set { self[SettingsAppearancePaletteKey.self] = newValue }
    }
}

struct SettingsPaletteDivider: View {
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: SettingsLayoutMetrics.dividerWidth)
    }
}
