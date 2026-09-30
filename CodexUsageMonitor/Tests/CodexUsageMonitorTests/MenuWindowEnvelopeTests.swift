import CoreGraphics
import XCTest
@testable import CodexUsageMonitor

final class MenuWindowEnvelopeTests: XCTestCase {
    /// A shrink proposed for shorter content must not land after a newer,
    /// taller commit has grown the window; that would clip the new content.
    func testStaleShrinkIsDroppedAfterNewerGrow() {
        var envelope = MenuWindowEnvelope(cap: 860)
        XCTAssertEqual(envelope.prepare(committing: 600), 600)
        XCTAssertEqual(envelope.settle(measured: 600), .unchanged)

        guard case let .shrink(to: shorter, generation: proposed) = envelope.settle(measured: 400) else {
            return XCTFail("Shorter settled content should propose a shrink")
        }
        XCTAssertEqual(envelope.prepare(committing: 700), 700)

        XCTAssertFalse(envelope.applyShrink(to: shorter, generation: proposed))
        XCTAssertGreaterThanOrEqual(envelope.windowHeight, 700)
    }
}
