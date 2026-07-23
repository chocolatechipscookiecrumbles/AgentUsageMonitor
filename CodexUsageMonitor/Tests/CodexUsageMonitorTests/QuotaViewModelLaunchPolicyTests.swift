import XCTest
@testable import CodexUsageMonitor

@MainActor
final class QuotaViewModelLaunchPolicyTests: XCTestCase {
    func testWindowPopoverGateDoesNotStartProviderMonitoring() {
        XCTAssertFalse(
            QuotaViewModel.shouldStartProviderMonitoring(
                arguments: ["CodexUsageMonitor", MenuPopoverViabilityGate.launchArgument]
            )
        )
    }
}
