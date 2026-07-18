import SwiftUI

struct SettingsPageHeader: View {
    let title: String
    @Binding var isPreviewVisible: Bool
    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Spacer(minLength: 0)

            Button(
                isPreviewVisible ? "Hide Context Rail" : "Show Context Rail",
                systemImage: "sidebar.right",
                action: togglePreview
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityLabel(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
            .accessibilityValue(isPreviewVisible ? "Visible" : "Hidden")
            .help(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
        }
        .padding(.horizontal, 20)
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .background(palette.windowBackground)
    }

    private func togglePreview() {
        isPreviewVisible.toggle()
    }
}
