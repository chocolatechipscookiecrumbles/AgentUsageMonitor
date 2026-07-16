import SwiftUI

struct SettingsPageHeader: View {
    let title: String
    @Binding var isPreviewVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Spacer(minLength: 0)

            Button(
                isPreviewVisible ? "Hide Preview" : "Show Preview",
                systemImage: "sidebar.right",
                action: togglePreview
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(isPreviewVisible ? "Hide Preview" : "Show Preview")
        }
        .padding(.horizontal, 20)
        .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func togglePreview() {
        isPreviewVisible.toggle()
    }
}
