import SwiftUI

struct SettingsSectionRow<Content: View>: View {
    let showsDivider: Bool
    private let content: Content

    init(showsDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, SettingsLayoutMetrics.sectionRowVerticalPadding)

            if showsDivider {
                SettingsPaletteDivider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
