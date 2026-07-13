import Foundation

enum CodexAccountStatus: Sendable {
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
    let accountStatus: CodexAccountStatus
    let planName: String?
    let confirmation: ConfirmationState
    let collectedAt: Date
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
        presentation: QuotaPresentation,
        refreshState: RefreshState,
        diagnostics: RefreshDiagnosticSummary,
        bundle: Bundle = .main
    ) -> SettingsStatus {
        let accountStatus: CodexAccountStatus
        if presentation.accountFingerprint != nil,
           presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry {
            accountStatus = .connected
        } else if presentation.accountFingerprint != nil,
                  presentation.confirmation == .cachedLastKnownGood {
            accountStatus = .cached
        } else {
            accountStatus = .unavailable
        }

        return SettingsStatus(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local",
            accountStatus: accountStatus,
            planName: presentation.planType?.capitalized,
            confirmation: presentation.confirmation,
            collectedAt: presentation.collectedAt,
            refreshState: refreshState,
            diagnostics: diagnostics
        )
    }
}
