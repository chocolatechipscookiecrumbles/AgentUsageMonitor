import SwiftUI
import XCTest
@testable import CodexUsageMonitor

/// The provider tint is added once and read by the tab underline, both quota
/// bars, the warning chips, and the rail card. A wrong value there is wrong
/// everywhere at once, so it is pinned here rather than eyeballed per surface.
final class AgentProviderPresentationTests: XCTestCase {
    func testClaudeUsesItsBrandTintNotSystemOrange() {
        XCTAssertEqual(
            AgentProvider.claudeCode.settingsPresentationTint,
            Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
        )
        XCTAssertNotEqual(
            AgentProvider.claudeCode.settingsPresentationTint,
            .orange,
            "system orange is the placeholder the port was supposed to replace"
        )
    }

    func testCodexTintIsUnchanged() {
        XCTAssertEqual(
            AgentProvider.codex.settingsPresentationTint,
            Color(red: 87 / 255, green: 109 / 255, blue: 1)
        )
    }

    /// A provider "enters the selector" through the catalog, so this entry is
    /// the record of whether Claude is a real page or a placeholder.
    func testCatalogMarksClaudeSupported() {
        let claude = AgentSettingsCatalog.entries.first { $0.provider == .claudeCode }
        XCTAssertEqual(claude?.availability, .supported)
    }

    func testCatalogStillOmitsCopilot() {
        XCTAssertFalse(AgentSettingsCatalog.entries.contains { $0.provider == .githubCopilot })
    }
}
