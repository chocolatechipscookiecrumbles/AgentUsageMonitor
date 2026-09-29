import AppKit
import Combine

/// Produces the panel's display state. The panel observes `willChange`, never
/// the underlying models, so every change goes through the measure-then-grow
/// pipeline before SwiftUI sees it.
@MainActor
protocol MenuSnapshotSource: AnyObject {
    var initialSelection: AgentProvider { get }
    /// Fires before any displayed value changes.
    var willChange: AnyPublisher<Void, Never> { get }
    func state(for selection: AgentProvider) -> MenuPanelState
    /// Called before the state for a newly selected provider is built.
    func select(_ provider: AgentProvider)
    func refresh(_ provider: AgentProvider)
    func connect(_ provider: AgentProvider)
    func signInWithBrowser()
    func signInWithCLI()
    func openSystemNotificationSettings()
    func nextFixture()
}

/// Real usage from the app's single `QuotaViewModel`.
@MainActor
final class LiveMenuSnapshotSource: MenuSnapshotSource {
    private let viewModel: QuotaViewModel

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
    }

    var initialSelection: AgentProvider {
        MenuPopoverProviderCatalog.resolvedSelection(viewModel.settings.selectedMenuProvider)
    }

    var willChange: AnyPublisher<Void, Never> {
        viewModel.objectWillChange
            .merge(with: viewModel.settings.objectWillChange, viewModel.enrollment.objectWillChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func state(for selection: AgentProvider) -> MenuPanelState {
        let provider = MenuPopoverProviderCatalog.resolvedSelection(selection)
        return MenuPanelState(
            selection: provider,
            snapshot: .live(viewModel, provider: provider),
            keyboardShortcutsEnabled: viewModel.settings.keyboardShortcutsEnabled,
            diagnosticLabel: nil
        )
    }

    /// Persist the resolved tab so it is restored on the next launch.
    func select(_ provider: AgentProvider) {
        viewModel.settings.selectedMenuProvider = MenuPopoverProviderCatalog.resolvedSelection(provider)
    }

    func refresh(_ provider: AgentProvider) {
        switch provider {
        case .codex: viewModel.refresh()
        case .claudeCode: viewModel.refreshClaude()
        case .githubCopilot: break
        }
    }

    func connect(_ provider: AgentProvider) {
        switch provider {
        case .codex: viewModel.connectCodex()
        case .claudeCode: viewModel.connectClaude()
        case .githubCopilot: break
        }
    }

    func signInWithBrowser() { viewModel.signInWithBrowser() }
    func signInWithCLI() { viewModel.signInWithCLI() }
    func openSystemNotificationSettings() { viewModel.openNotificationSettings() }
    func nextFixture() {}
}

/// Synthetic states for recordings. Never constructs monitoring services or
/// touches real settings, accounts or credentials; account actions are inert.
@MainActor
final class FixtureMenuSnapshotSource: MenuSnapshotSource {
    private let changes = PassthroughSubject<Void, Never>()
    private var provider: AgentProvider = .codex
    private var fixtureIndex = 0
    private let now = Date()

    var initialSelection: AgentProvider { .codex }
    var willChange: AnyPublisher<Void, Never> { changes.eraseToAnyPublisher() }

    func state(for selection: AgentProvider) -> MenuPanelState {
        let provider = MenuPopoverProviderCatalog.resolvedSelection(selection)
        let labels = MenuContentSnapshot.fixtureLabels(for: provider)
        return MenuPanelState(
            selection: provider,
            snapshot: .fixture(provider: provider, index: fixtureIndex, now: now),
            keyboardShortcutsEnabled: false,
            diagnosticLabel: "Diagnostic · \(labels[fixtureIndex % labels.count]) · Account actions disabled"
        )
    }

    /// Each provider's replay starts from its first state.
    func select(_ provider: AgentProvider) {
        if provider != self.provider { fixtureIndex = 0 }
        self.provider = provider
    }

    func nextFixture() {
        changes.send()
        fixtureIndex = (fixtureIndex + 1) % MenuContentSnapshot.fixtureLabels(for: provider).count
    }

    func refresh(_ provider: AgentProvider) {}
    func connect(_ provider: AgentProvider) {}
    func signInWithBrowser() {}
    func signInWithCLI() {}
    func openSystemNotificationSettings() {}
}
