import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var systemAppearance = SystemAppearanceObserver()
    @State private var isPreviewVisible = false

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        let layout = SettingsWindowLayout(isContextRailVisible: isPreviewVisible)

        HStack(spacing: 0) {
            SettingsNavigationSidebar(selection: $settings.selectedSettingsTab)

            Divider()

            settingsPage
                .frame(width: layout.settingsPageWidth, height: layout.contentSize.height)

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
        .frame(width: layout.contentSize.width, height: layout.contentSize.height)
        .background(SettingsWindowWidthAnchor(contentSize: layout.contentSize))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isPreviewVisible)
        .preferredColorScheme(
            settings.appearancePreference.presentationColorScheme(
                system: systemAppearance.colorScheme
            )
        )
    }

    private var settingsPage: some View {
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
    }
}
