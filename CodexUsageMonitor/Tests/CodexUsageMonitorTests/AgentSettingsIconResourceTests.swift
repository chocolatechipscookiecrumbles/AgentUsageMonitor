import XCTest
@testable import CodexUsageMonitor

final class AgentSettingsIconResourceTests: XCTestCase {
    func test_resolvesBundledFileNamesForVisibleAgents() {
        XCTAssertEqual(AgentSettingsIconResource.fileName(for: .codex), "codex-agent.png")
        XCTAssertEqual(AgentSettingsIconResource.fileName(for: .claudeCode), "claude-code-agent.png")
    }
}
