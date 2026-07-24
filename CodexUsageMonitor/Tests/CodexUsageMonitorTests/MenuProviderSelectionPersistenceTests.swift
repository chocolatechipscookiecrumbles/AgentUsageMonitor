import XCTest
@testable import CodexUsageMonitor

/// Task 7: the popover's selected tab round-trips through `AppSettings`, and an
/// unsupported persisted selection falls back rather than leaving an empty tab.
@MainActor
final class MenuProviderSelectionPersistenceTests: XCTestCase {
    func testSelectedMenuProviderDefaultsToCodex() {
        withDefaults { defaults in
            XCTAssertEqual(AppSettings(defaults: defaults).selectedMenuProvider, .codex)
        }
    }

    func testSelectedMenuProviderPersistsAcrossSettingsInstances() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            settings.selectedMenuProvider = .claudeCode

            XCTAssertEqual(AppSettings(defaults: defaults).selectedMenuProvider, .claudeCode)
        }
    }

    private func withDefaults(_ operation: (UserDefaults) -> Void) {
        let suiteName = "MenuProviderSelectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        operation(defaults)
    }
}

/// The resolution rule the persisted selection is read through: a *supported*
/// provider is honored even with no current snapshot; only an *unsupported* one
/// falls back to Codex.
final class MenuPopoverProviderResolutionTests: XCTestCase {
    func testSupportedProviderStaysSelected() {
        XCTAssertTrue(MenuPopoverProviderCatalog.availableProviders.contains(.claudeCode))
        XCTAssertEqual(MenuPopoverProviderCatalog.resolvedSelection(.claudeCode), .claudeCode)
    }

    func testUnsupportedProviderFallsBackToCodex() {
        // Copilot is unsupported, so restoring it must not leave the popover on
        // an empty tab.
        XCTAssertFalse(MenuPopoverProviderCatalog.availableProviders.contains(.githubCopilot))
        XCTAssertEqual(MenuPopoverProviderCatalog.resolvedSelection(.githubCopilot), .codex)
    }

    func testNoRequestResolvesToCodex() {
        XCTAssertEqual(MenuPopoverProviderCatalog.resolvedSelection(nil), .codex)
    }

    func testResolutionAlwaysYieldsASupportedProvider() {
        for provider in AgentProvider.allCases {
            let resolved = MenuPopoverProviderCatalog.resolvedSelection(provider)
            XCTAssertTrue(MenuPopoverProviderCatalog.availableProviders.contains(resolved))
        }
    }
}
