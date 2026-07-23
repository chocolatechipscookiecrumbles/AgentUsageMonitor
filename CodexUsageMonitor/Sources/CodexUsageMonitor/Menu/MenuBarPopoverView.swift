import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: QuotaViewModel
    @State private var selectedProvider: AgentProvider

    init(
        viewModel: QuotaViewModel,
        initialProvider: AgentProvider? = nil
    ) {
        self.viewModel = viewModel
        _selectedProvider = State(
            initialValue: MenuPopoverProviderCatalog.resolvedSelection(initialProvider)
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

                MenuActionFooter(
                    isRefreshing: isRefreshing,
                    refresh: refresh,
                    openNotificationSettings: showNotificationSettings,
                    openPreferences: showPreferences,
                    quit: quit
                )
            }
        }
    }

    private var activeProvider: AgentProvider {
        MenuPopoverProviderCatalog.resolvedSelection(selectedProvider)
    }

    private var headerPresentation: MenuProviderHeaderPresentation {
        switch activeProvider {
        case .codex:
            .codex(
                displayState: viewModel.displayState,
                isRefreshing: viewModel.isRefreshing
            )
        case .claudeCode:
            .claude(
                usageState: viewModel.claudeState,
                isRefreshing: viewModel.isRefreshingClaude
            )
        case .githubCopilot:
            .codex(
                displayState: viewModel.displayState,
                isRefreshing: viewModel.isRefreshing
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
        switch activeProvider {
        case .codex:
            CodexMenuContent(viewModel: viewModel)
        case .claudeCode, .githubCopilot:
            MenuProviderContentPlaceholder()
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
                .padding(.bottom, MenuPopoverTheme.contentBottomPadding)
        }
    }

    private func refresh() {
        dismiss()
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
