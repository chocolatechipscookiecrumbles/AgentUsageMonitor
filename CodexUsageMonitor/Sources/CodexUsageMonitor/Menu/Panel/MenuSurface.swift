import SwiftUI

/// The panel's single renderer for live and fixture data: tabs, provider
/// header, scrolling provider viewport and command footer.
struct MenuSurface: View {
    let state: MenuPanelState
    let maximumHeight: CGFloat
    let actions: MenuSurfaceActions
    var onSettledHeight: (CGFloat) -> Void = { _ in }

    var body: some View {
        MenuViewportLayout(maximumHeight: maximumHeight) {
            header
            viewport
            footer
        }
        .frame(width: MenuPopoverTheme.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onSettledHeight($0) }
        .onExitCommand(perform: actions.dismiss)
    }

    /// The strip keeps its Binding API. Reads come from published state;
    /// writes become an intent, so pointer and focus + Return selection both
    /// go through the controller's measure-then-grow pipeline.
    private var selection: Binding<AgentProvider> {
        Binding(get: { state.selection }, set: { actions.select($0) })
    }

    private var snapshot: MenuContentSnapshot { state.snapshot }
    private var isFixture: Bool { state.diagnosticLabel != nil }

    private var header: some View {
        VStack(spacing: 0) {
            if let diagnosticLabel = state.diagnosticLabel {
                HStack {
                    Text(diagnosticLabel)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button("Next state", action: actions.nextFixture)
                        .font(.caption)
                }
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
                .padding(.vertical, 6)
            }
            MenuProviderTabStrip(
                providers: MenuPopoverProviderCatalog.availableProviders,
                selection: selection
            )
            MenuProviderHeader(provider: snapshot.provider, presentation: snapshot.header)
        }
    }

    private var viewport: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                providerContent
                    .disabled(isFixture)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, MenuPopoverTheme.providerContentFooterSpacing)
                    .id(Self.contentTop)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: state.selection) { _, _ in
                proxy.scrollTo(Self.contentTop, anchor: .top)
            }
        }
    }

    private static let contentTop = "menu-content-top"

    private var footer: some View {
        MenuActionFooterRows(
            keyboardShortcutsEnabled: state.keyboardShortcutsEnabled,
            isRefreshing: snapshot.isRefreshing,
            isRefreshEnabled: snapshot.mode == .operational,
            allowsCommands: !isFixture,
            refresh: actions.refresh,
            openNotificationSettings: actions.openNotificationSettings,
            openPreferences: actions.openPreferences,
            quit: actions.quit
        )
    }

    @ViewBuilder
    private var providerContent: some View {
        switch (snapshot.provider, snapshot.mode) {
        case (.githubCopilot, _):
            MenuProviderContentPlaceholder()
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        case (let provider, .connectOnly):
            ProviderConnectCard(provider: provider, connect: actions.connect)
                .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        case (.codex, .operational):
            CodexMenuContentRender(
                presentation: snapshot.codexPresentation,
                connectionState: snapshot.codexConnection,
                activity: snapshot.activity,
                visibleActivitySections: snapshot.visibleActivitySections,
                showsNotificationPermission: snapshot.showsNotificationPermission,
                signInWithBrowser: actions.signInWithBrowser,
                signInWithCLI: actions.signInWithCLI,
                openSystemNotificationSettings: actions.openSystemNotificationSettings
            )
        case (.claudeCode, .operational):
            ClaudeMenuContentRender(
                model: snapshot.claudeModel,
                monitoringStatus: snapshot.claudeStatus,
                connectionState: snapshot.claudeConnection,
                activity: snapshot.activity,
                visibleActivitySections: snapshot.visibleActivitySections,
                showsNotificationPermission: snapshot.showsNotificationPermission,
                connect: actions.connect,
                openSystemNotificationSettings: actions.openSystemNotificationSettings
            )
        }
    }
}
