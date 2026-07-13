import Foundation

enum CodexAgentStatus: Sendable {
    case connected
    case cached
    case unavailable

    var displayName: String {
        switch self {
        case .connected: "Connected"
        case .cached: "Last confirmed account cached"
        case .unavailable: "Not currently detected"
        }
    }
}

struct SettingsStatus: Sendable {
    let appVersion: String
    let buildNumber: String
    let codexStatus: CodexAgentStatus
    let planName: String?
    let displayMode: QuotaDisplayMode
    let pauseReason: QuotaPauseReason?
    let lastAttemptAt: Date
    let lastConfirmedAt: Date?
    let refreshState: RefreshState
    let diagnostics: RefreshDiagnosticSummary

    var refreshActivity: String {
        switch refreshState {
        case .idle: "Idle"
        case .refreshing(let reason): "Refreshing (\(reason.rawValue))"
        case .failed: "Last refresh unavailable"
        }
    }

    static func make(
        displayState: QuotaDisplayState,
        refreshState: RefreshState,
        diagnostics: RefreshDiagnosticSummary,
        bundle: Bundle = .main
    ) -> SettingsStatus {
        let codexStatus: CodexAgentStatus
        let presentation = displayState.displayedRecord?.presentation
            ?? QuotaPresentation.unavailable("No confirmed quota result is available.")
        if presentation.accountFingerprint != nil,
           displayState.mode == .confirmedCompleted {
            codexStatus = .connected
        } else if presentation.accountFingerprint != nil {
            codexStatus = .cached
        } else {
            codexStatus = .unavailable
        }

        return SettingsStatus(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local",
            codexStatus: codexStatus,
            planName: presentation.planType?.capitalized,
            displayMode: displayState.mode,
            pauseReason: displayState.pauseReason,
            lastAttemptAt: displayState.lastAttemptAt,
            lastConfirmedAt: displayState.lastConfirmedAt,
            refreshState: refreshState,
            diagnostics: diagnostics
        )
    }
}
