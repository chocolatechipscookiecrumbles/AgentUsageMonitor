import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var systemAppearance = SystemAppearanceObserver()
    @State private var isPreviewVisible = true

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsNavigationSidebar(selection: $settings.selectedSettingsTab)

            Divider()

            VStack(spacing: 0) {
                SettingsPageHeader(
                    title: settings.selectedSettingsTab.title,
                    isPreviewVisible: $isPreviewVisible
                )

                Divider()

                SettingsDetailView(
                    selection: settings.selectedSettingsTab,
                    viewModel: viewModel,
                    launchAtLogin: launchAtLogin
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPreviewVisible {
                Divider()

                SettingsContextPanel {
                    SettingsPreviewView(
                        selection: settings.selectedSettingsTab,
                        viewModel: viewModel
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: SettingsLayoutMetrics.windowWidth, height: SettingsLayoutMetrics.windowHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isPreviewVisible)
        .preferredColorScheme(
            settings.appearancePreference.presentationColorScheme(
                system: systemAppearance.colorScheme
            )
        )
    }
}
