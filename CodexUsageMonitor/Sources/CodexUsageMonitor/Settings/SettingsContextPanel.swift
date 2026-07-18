import SwiftUI

struct SettingsContextPanel<Content: View>: View {
    private let content: Content
    @Environment(\.settingsAppearancePalette) private var palette

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .frame(width: SettingsLayoutMetrics.contextRailWidth)
        .background(palette.contextRailBackground)
    }
}
