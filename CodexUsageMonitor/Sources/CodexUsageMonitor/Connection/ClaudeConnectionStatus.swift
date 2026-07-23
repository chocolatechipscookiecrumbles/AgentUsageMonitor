import Foundation

/// The single answer to "is Claude connected?", shared by the agent page and
/// the context rail so the two cannot disagree.
///
/// Previously each surface decided for itself and they contradicted each
/// other: the rail treated *any* usage data as a connection, so a 47-hour-old
/// cache read "Connected", while the page reported the sign-in button's state,
/// so a working live read showed "Disconnected" until somebody pressed it.
///
/// **Connected means the most recent refresh authenticated and returned a live
/// read.** Cached or passively-captured numbers are data we happen to hold,
/// not evidence that the credential currently works — which is exactly what
/// the status row is being asked.
struct ClaudeConnectionStatus: Equatable {
    let isConnected: Bool
    let text: String
    let detail: String?

    static func resolve(
        signInState: ClaudeConnectionState,
        usageState: ClaudeUsageState
    ) -> ClaudeConnectionStatus {
        // A live read proves the credential works right now, so it supersedes
        // an older failure rather than leaving the page contradicting itself.
        let hasLiveRead = usageState.presentation?.delivery == .live

        switch signInState {
        case .signingIn(let method):
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Signing in with \(method.displayName)…",
                detail: nil
            )
        case .checking:
            return ClaudeConnectionStatus(isConnected: false, text: "Checking…", detail: nil)
        case .failed(let failure) where !hasLiveRead:
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Needs attention",
                detail: failure.displayMessage
            )
        case .missingCLI where !hasLiveRead:
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Not connected",
                detail: ClaudeConnectionFailure.missingClaudeCLI.displayMessage
            )
        default:
            break
        }

        guard hasLiveRead else {
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Not connected",
                detail: nil
            )
        }
        return ClaudeConnectionStatus(isConnected: true, text: "Connected", detail: nil)
    }
}
