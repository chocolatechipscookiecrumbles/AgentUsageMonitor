import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: QuotaViewModel
    /// Observed separately so recording enrollment redraws an open popover the
    /// same way a Token Monitor preference change does.
    @ObservedObject var enrollment: ProviderEnrollmentStore
    @State private var selectedProvider: AgentProvider

    init(
        viewModel: QuotaViewModel,
        initialProvider: AgentProvider? = nil
    ) {
        self.viewModel = viewModel
        enrollment = viewModel.enrollment
        // An explicit caller request wins; otherwise restore the last-viewed
        // tab. Either is resolved against the supported catalog so an
        // unsupported persisted provider falls back to Codex.
        let requested = initialProvider ?? viewModel.settings.selectedMenuProvider
        _selectedProvider = State(
            initialValue: MenuPopoverProviderCatalog.resolvedSelection(requested)
        )
    }

    var body: some View {
        MenuPopoverChrome {
            VStack(spacing: 0) {
                MenuProviderTabStrip(
                    providers: MenuPopoverProviderCatalog.availableProviders,
                    selection: $selectedProvider
                )

                MenuProviderHeader(
                    provider: activeProvider,
                    presentation: headerPresentation
                )

                providerContent
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, MenuPopoverTheme.providerContentFooterSpacing)

                MenuActionFooter(
                    settings: viewModel.settings,
                    isRefreshing: isRefreshing,
                    // A connect-only tab has nothing to refresh, and a Refresh
                    // that silently enrolled would defeat the explicit consent
                    // this whole gate exists for.
                    isRefreshEnabled: menuMode == .operational,
                    refresh: refresh,
                    openNotificationSettings: showNotificationSettings,
                    openPreferences: showPreferences,
                    quit: quit
                )
            }
            .onChange(of: selectedProvider) { _, newValue in
                // Persist the resolved (always-supported) tab so it is restored
                // on the next launch.
                viewModel.settings.selectedMenuProvider =
                    MenuPopoverProviderCatalog.resolvedSelection(newValue)
            }
            .onExitCommand {
                dismiss()
            }
        }
    }

    private var activeProvider: AgentProvider {
        MenuPopoverProviderCatalog.resolvedSelection(selectedProvider)
    }

    /// Enrollment is resolved before any provider state is read, so an
    /// unenrolled tab cannot be promoted by a cached reading.
    private var menuMode: ProviderMenuMode {
        ProviderMenuMode.resolve(policy: viewModel.runtimePolicy(for: activeProvider))
    }

    private var headerPresentation: MenuProviderHeaderPresentation {
        guard menuMode == .operational else {
            return .connectOnly(provider: activeProvider)
        }
        return switch activeProvider {
        case .codex, .githubCopilot:
            .codex(
                displayState: viewModel.displayState,
                connectionState: viewModel.connectionState,
                isRefreshing: viewModel.isRefreshing
            )
        case .claudeCode:
            .claude(
                usageState: viewModel.claudeState,
                connectionState: viewModel.claudeConnectionState,
                isRefreshing: viewModel.isRefreshingClaude
            )
        }
    }

    private var isRefreshing: Bool {
        switch activeProvider {
        case .codex:
            viewModel.isRefreshing
        case .claudeCode:
            viewModel.isRefreshingClaude
        case .githubCopilot:
            false
        }
    }

    @ViewBuilder
    private var providerContent: some View {
        switch (activeProvider, menuMode) {
        case (.githubCopilot, _):
            MenuProviderContentPlaceholder()
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        case (let provider, .connectOnly):
            ProviderConnectCard(provider: provider) { connect(provider) }
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        case (.codex, .operational):
            CodexMenuContent(viewModel: viewModel, settings: viewModel.settings)
        case (.claudeCode, .operational):
            ClaudeMenuContent(viewModel: viewModel, settings: viewModel.settings)
        }
    }

    private func connect(_ provider: AgentProvider) {
        switch provider {
        case .codex:
            viewModel.connectCodex()
        case .claudeCode:
            viewModel.connectClaude()
        case .githubCopilot:
            break
        }
    }

    private func refresh() {
        switch activeProvider {
        case .codex:
            viewModel.refresh()
        case .claudeCode:
            viewModel.refreshClaude()
        case .githubCopilot:
            break
        }
    }

    private func showNotificationSettings() {
        dismiss()
        viewModel.settings.selectedSettingsTab = .notifications
        openAppSettings()
    }

    private func showPreferences() {
        dismiss()
        viewModel.settings.selectedSettingsTab = .general
        openAppSettings()
    }

    private func openAppSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func quit() {
        dismiss()
        NSApplication.shared.terminate(nil)
    }
}
