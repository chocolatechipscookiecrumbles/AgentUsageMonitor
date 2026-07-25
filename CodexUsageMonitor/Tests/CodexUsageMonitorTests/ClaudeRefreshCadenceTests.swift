import XCTest
@testable import CodexUsageMonitor

final class ClaudeRefreshCadenceTests: XCTestCase {
    /// The shared setting must not drive Claude's networked read faster than the
    /// endpoint safely tolerates: sub-floor fixed modes clamp up to the floor.
    func testSubFloorFixedModesClampToNetworkFloor() {
        XCTAssertEqual(ClaudeRefreshCadence.pollInterval(for: .ninetySeconds), ClaudeRefreshCadence.networkFloor)
        XCTAssertEqual(ClaudeRefreshCadence.pollInterval(for: .twoMinutes), ClaudeRefreshCadence.networkFloor)
        XCTAssertEqual(ClaudeRefreshCadence.pollInterval(for: .fiveMinutes), ClaudeRefreshCadence.networkFloor)
    }

    /// Modes at or above the floor pass through unchanged, so the user's slower
    /// choices are still honored exactly.
    func testModesAtOrAboveFloorArePreserved() {
        XCTAssertEqual(ClaudeRefreshCadence.pollInterval(for: .tenMinutes), .seconds(600))
    }

    /// Automatic resolves to the floor: Claude does not burst on the network the
    /// way Codex's local read does.
    func testAutomaticResolvesToNetworkFloor() {
        XCTAssertEqual(ClaudeRefreshCadence.pollInterval(for: .automatic), ClaudeRefreshCadence.networkFloor)
    }

    /// No mode may ever produce a networked interval below the safety floor.
    func testNoModePollsFasterThanTheFloor() {
        for mode in RefreshMode.allCases {
            XCTAssertGreaterThanOrEqual(
                ClaudeRefreshCadence.pollInterval(for: mode),
                ClaudeRefreshCadence.networkFloor,
                "\(mode) must not poll Claude faster than the network floor"
            )
        }
    }
}
