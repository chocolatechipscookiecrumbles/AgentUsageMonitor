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

    /// A plain-text rendering of exactly what the Diagnostics page shows, so a
    /// pasted report cannot disagree with the page it was copied from. It
    /// carries the same stable classifications the page does — never raw
    /// provider error text or quota values.
    func diagnosticsReport(now: Date = .now) -> String {
        var lines = [
            "Codex Usage Monitor diagnostics",
            "Copied: \(now.formatted(date: .abbreviated, time: .shortened))",
            "Version: \(appVersion) (\(buildNumber))",
            "",
            "Latest refresh",
            "  Status: \(displayMode.displayName)",
            "  Last attempt: \(lastAttemptAt.formatted(date: .abbreviated, time: .shortened))",
        ]
        if let lastConfirmedAt {
            lines.append("  Last confirmed: \(lastConfirmedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        lines.append("  Activity: \(refreshActivity)")

        lines.append(contentsOf: ["", "Outcomes · last 30 days"])
        if diagnostics.outcomes.isEmpty {
            lines.append("  No recorded outcomes")
        } else {
            for outcome in Self.outcomeOrder {
                if let count = diagnostics.outcomes[outcome] {
                    lines.append("  \(outcome.displayName): \(count.formatted())")
                }
            }
        }

        lines.append(contentsOf: ["", "Classified failures · last 30 days"])
        if diagnostics.failureKinds.isEmpty {
            lines.append("  No classified failures")
        } else {
            for kind in diagnostics.failureKinds.keys.sorted() {
                lines.append("  \(kind): \(diagnostics.failureKinds[kind, default: 0].formatted())")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Shared by the page and the copied report so both list outcomes in the
    /// same order.
    static let outcomeOrder: [RefreshOutcome] = [
        .confirmed,
        .confirmedAfterRetry,
        .cachedLastKnownGood,
        .unconfirmed,
        .unavailable,
    ]

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
            planName: AgentPlanName.display(presentation.planType),
            displayMode: displayState.mode,
            pauseReason: displayState.pauseReason,
            lastAttemptAt: displayState.lastAttemptAt,
            lastConfirmedAt: displayState.lastConfirmedAt,
            refreshState: refreshState,
            diagnostics: diagnostics
        )
    }
}
