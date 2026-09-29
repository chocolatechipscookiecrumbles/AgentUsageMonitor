import Foundation

/// Monitoring enrollment is independent of the optional live credential.
/// Shared by Settings, the menu, and the context rail.
struct ClaudeConnectionStatus: Equatable {
    let isMonitoringEnabled: Bool
    let text: String
    let detail: String?

    static func resolve(
        isEnrolled: Bool,
        signInState: ClaudeConnectionState,
        usageState: ClaudeUsageState
    ) -> ClaudeConnectionStatus {
        guard isEnrolled else {
            return Self(isMonitoringEnabled: false, text: "Not connected", detail: nil)
        }
        let detail: String?
        switch signInState {
        case .connecting, .checking:
            detail = "Checking live fallback. Passive monitoring remains enabled."
        case .failed:
            detail = "Live fallback unavailable. Passive monitoring remains enabled."
        case .notConnected, .connected:
            switch usageState {
            case .available(let presentation): detail = presentation.warnings.first
            case .unavailable(let reason):
                detail = reason == ClaudeUsageState.notConnectedReason ? nil : reason
            }
        }
        return Self(isMonitoringEnabled: true, text: "Monitoring enabled", detail: detail)
    }
}
