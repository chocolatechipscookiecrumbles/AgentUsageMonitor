import Foundation

enum ClaudeSetupState: Equatable {
    case checking
    case notSetUp
    case existingSetup

    /// Onboarding is only for a genuinely untouched provider. Any reading is
    /// evidence that setup worked before, while an in-progress or failed
    /// connection needs its existing status and recovery details to remain
    /// visible.
    static func resolve(
        connectionState: ClaudeConnectionState,
        usageState: ClaudeUsageState,
        hasSetupHistory: Bool,
        hasCompletedSourceDiscovery: Bool
    ) -> ClaudeSetupState {
        guard !hasSetupHistory, usageState.presentation == nil else {
            return .existingSetup
        }
        guard hasCompletedSourceDiscovery else {
            return .checking
        }
        guard connectionState == .notConnected else {
            return .existingSetup
        }
        return .notSetUp
    }

    static func hasCurrentEvidence(
        connectionState: ClaudeConnectionState,
        usageState: ClaudeUsageState
    ) -> Bool {
        connectionState.isConnected || usageState.presentation != nil
    }
}
