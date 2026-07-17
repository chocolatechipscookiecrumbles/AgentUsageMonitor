import XCTest
@testable import CodexUsageMonitor

final class SettingsWindowLayoutTests: XCTestCase {
    func test_contextRailOnlyChangesTheRightHandWindowAllocation() {
        let hidden = SettingsWindowLayout(isContextRailVisible: false)
        let visible = SettingsWindowLayout(isContextRailVisible: true)

        XCTAssertEqual(hidden.sidebarWidth, visible.sidebarWidth)
        XCTAssertEqual(hidden.settingsPageWidth, visible.settingsPageWidth)
        XCTAssertEqual(hidden.contentSize.height, visible.contentSize.height)
        XCTAssertEqual(
            hidden.contentSize,
            CGSize(
                width: SettingsLayoutMetrics.hiddenWindowWidth,
                height: SettingsLayoutMetrics.targetWindowHeight
            )
        )
        XCTAssertEqual(
            visible.contentSize,
            CGSize(
                width: SettingsLayoutMetrics.hiddenWindowWidth
                    + SettingsLayoutMetrics.contextRailWidth
                    + SettingsLayoutMetrics.dividerWidth,
                height: SettingsLayoutMetrics.targetWindowHeight
            )
        )
        XCTAssertEqual(
            visible.contentSize.width - hidden.contentSize.width,
            SettingsLayoutMetrics.contextRailWidth + SettingsLayoutMetrics.dividerWidth
        )
    }
}
