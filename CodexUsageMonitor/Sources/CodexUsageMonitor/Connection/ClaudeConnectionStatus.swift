import Foundation

/// The single answer to "is Claude connected?", shared by the agent page and
/// the context rail so the two cannot disagree.
///
/// Previously each surface decided for itself and they contradicted each
/// other: the rail treated *any* usage data as a connection, so a 47-hour-old
/// cache read "Connected", while the page reported the sign-in button's state,
/// so a working live read showed "Disconnected" until somebody pressed it.
///
/// **Connected means an explicit successful connection or a live OAuth read.**
/// CLI, cached, and passively-captured numbers are data we happen to hold, not
/// evidence that the borrowed Keychain credential currently works.
struct ClaudeConnectionStatus: Equatable {
    let isConnected: Bool
    let text: String
    let detail: String?

    static func resolve(
        signInState: ClaudeConnectionState,
        usageState: ClaudeUsageState
    ) -> ClaudeConnectionStatus {
        // A successful OAuth request proves the borrowed credential works
        // right now. Other fresh sources, including the paid CLI probe, do
        // not exercise this app's Keychain grant.
        let hasLiveOAuthRead = usageState.presentation.map {
            $0.delivery == .live && $0.snapshot.source == .oauth
        } ?? false

        switch signInState {
        case .connecting:
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Connecting…",
                detail: "Approve the Keychain prompt and choose Always Allow."
            )
        case .checking:
            return ClaudeConnectionStatus(isConnected: false, text: "Checking…", detail: nil)
        case .failed(let failure) where !hasLiveOAuthRead:
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Needs attention",
                detail: failure.displayMessage
            )
        default:
            break
        }

        guard signInState.isConnected || hasLiveOAuthRead else {
            return ClaudeConnectionStatus(
                isConnected: false,
                text: "Not connected",
                detail: nil
            )
        }
        return ClaudeConnectionStatus(isConnected: true, text: "Connected", detail: nil)
    }

}
