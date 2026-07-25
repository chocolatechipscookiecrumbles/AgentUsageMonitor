import XCTest
@testable import CodexUsageMonitor

private actor StatusSequence {
    private var values: [AgentConnectionState]

    init(_ values: [AgentConnectionState]) {
        self.values = values
    }

    func next() -> AgentConnectionState {
        guard !values.isEmpty else { return .disconnected }
        return values.removeFirst()
    }
}

@MainActor
final class CodexConnectionControllerTests: XCTestCase {
    func test_activationRecheckConnectsOnceAfterExternalLogin() async {
        let center = NotificationCenter()
        let activation = Notification.Name("test.application-did-become-active")
        let sequence = StatusSequence([
            .disconnected,
            .connected(AgentAccountSummary(planType: "test")),
        ])
        var connectedCount = 0
        let controller = CodexConnectionController(
            onConnected: { connectedCount += 1 },
            statusReader: { await sequence.next() },
            notificationCenter: center,
            activationNotification: activation
        )

        controller.start()
        await waitForState(.disconnected, in: controller)
        center.post(name: activation, object: nil)
        await waitForState(.connected(AgentAccountSummary(planType: "test")), in: controller)
        center.post(name: activation, object: nil)
        await Task.yield()

        XCTAssertEqual(connectedCount, 1)
    }

    private let connected = AgentConnectionState.connected(AgentAccountSummary(planType: "test"))

    func test_disconnectStaysDisconnectedAndPersistsTheFlag() async {
        var disconnected = false
        let controller = CodexConnectionController(
            onConnected: {},
            statusReader: { [connected] in connected },
            isUserDisconnected: { disconnected },
            setUserDisconnected: { disconnected = $0 }
        )

        controller.start()
        await waitForState(connected, in: controller)

        controller.disconnect()

        XCTAssertTrue(disconnected, "disconnect must persist the flag")
        XCTAssertEqual(controller.state, .disconnected)
        // The still-valid credential must not auto-reconnect.
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(controller.state, .disconnected)
    }

    func test_startRespectsAPersistedDisconnect() async {
        var disconnected = true
        let controller = CodexConnectionController(
            onConnected: {},
            statusReader: { [connected] in connected },
            isUserDisconnected: { disconnected },
            setUserDisconnected: { disconnected = $0 }
        )

        controller.start()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(controller.state, .disconnected, "a persisted disconnect must not auto-detect the CLI")
    }

    func test_checkConnectionClearsTheDisconnectAndReconnects() async {
        var disconnected = true
        let controller = CodexConnectionController(
            onConnected: {},
            statusReader: { [connected] in connected },
            isUserDisconnected: { disconnected },
            setUserDisconnected: { disconnected = $0 }
        )

        controller.start()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(controller.state, .disconnected)

        controller.checkConnection()

        await waitForState(connected, in: controller)
        XCTAssertFalse(disconnected, "an explicit reconnect must clear the disconnect flag")
    }

    private func waitForState(
        _ expected: AgentConnectionState,
        in controller: CodexConnectionController
    ) async {
        for _ in 0..<100 where controller.state != expected {
            await Task.yield()
        }
        XCTAssertEqual(controller.state, expected)
    }
}
