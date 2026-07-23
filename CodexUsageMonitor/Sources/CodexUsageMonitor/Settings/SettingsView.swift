import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: QuotaViewModel
    @ObservedObject private var settings: AppSettings
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var systemAppearance = SystemAppearanceObserver()
    @State private var isPreviewVisible = false
    @State private var selectedSettingsAgent: AgentProvider = .codex

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        let layout = SettingsWindowLayout(isContextRailVisible: isPreviewVisible)

        HStack(spacing: 0) {
            SettingsNavigationSidebar(selection: $settings.selectedSettingsTab)

            verticalPaletteDivider

            settingsPage
                .frame(width: layout.settingsPageWidth, height: layout.contentSize.height)

            if isPreviewVisible {
                verticalPaletteDivider

                SettingsContextPanel {
                    SettingsPreviewView(
                        selection: settings.selectedSettingsTab,
                        viewModel: viewModel,
                        selectedAgent: selectedSettingsAgent,
                        connectionState: viewModel.connectionState,
                        settingsStatus: viewModel.settingsStatus
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height)
        .background(SettingsWindowWidthAnchor(contentSize: layout.contentSize))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isPreviewVisible)
        .environment(\.settingsAppearancePalette, appearancePalette)
        .preferredColorScheme(presentationColorScheme)
        .onAppear(perform: repairSelectedSettingsAgentIfNeeded)
        .onChange(of: selectedSettingsAgent) { _, provider in
            ProviderSwitchTrace.record(
                surface: .settingsAgents,
                phase: .selectionChanged,
                provider: provider
            )
        }
    }

    private var settingsPage: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(
                selection: settings.selectedSettingsTab,
                entries: AgentSettingsCatalog.entries,
                selectedAgent: $selectedSettingsAgent,
                isPreviewVisible: $isPreviewVisible
            )

            horizontalPaletteDivider

            SettingsDetailView(
                selection: settings.selectedSettingsTab,
                viewModel: viewModel,
                launchAtLogin: launchAtLogin,
                selectedSettingsAgent: selectedSettingsAgent
            )
        }
    }

    private func repairSelectedSettingsAgentIfNeeded() {
        guard !AgentSettingsCatalog.entries.contains(where: { $0.provider == selectedSettingsAgent }) else {
            return
        }

        selectedSettingsAgent = .codex
    }

    private var presentationColorScheme: ColorScheme {
        settings.appearancePreference.presentationColorScheme(system: systemAppearance.colorScheme)
    }

    private var appearancePalette: SettingsAppearancePalette {
        SettingsAppearancePalette.resolve(for: presentationColorScheme)
    }

    private var verticalPaletteDivider: some View {
        Rectangle()
            .fill(appearancePalette.divider)
            .frame(width: SettingsLayoutMetrics.dividerWidth)
    }

    private var horizontalPaletteDivider: some View {
        Rectangle()
            .fill(appearancePalette.divider)
            .frame(height: SettingsLayoutMetrics.dividerWidth)
    }
}
