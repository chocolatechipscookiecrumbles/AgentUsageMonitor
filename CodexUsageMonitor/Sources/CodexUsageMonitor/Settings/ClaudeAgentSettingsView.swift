import SwiftUI

/// Claude's Settings page, built on the same template as
/// `CodexAgentSettingsView`: a Connection section (status, plan, guidance,
/// actions) followed by the provider-neutral quota rows, so both agents read
/// as one system.
///
/// Claude has no credit balance or reset credits, so it uses
/// `AgentQuotaWindowRow` directly rather than `AgentQuotaSessionSection`
/// (which includes Codex-only credit rows).
struct ClaudeAgentSettingsView: View {
    let connectionState: ClaudeConnectionState
    let usageState: ClaudeUsageState
    let valueMode: QuotaValueMode
    let connectWithCredentials: () -> Void
    let disconnect: () -> Void
    let refresh: () -> Void

    private var model: ClaudeUsageDisplayModel? {
        usageState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) }
    }

    var body: some View {
        SettingsSection("Connection") {
            SettingsSectionRow {
                SettingsPreferenceControlRow("Status") { Text(connectionState.displayName) }
            }
            if let plan = planName {
                SettingsSectionRow {
                    SettingsPreferenceControlRow("Plan") { Text(plan) }
                }
            }
            SettingsSectionRow(showsDivider: false) {
                VStack(alignment: .leading, spacing: 8) {
                    connectionGuidance
                    connectionActions
                }
            }
        }

        SettingsSection("Current quota") {
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .fiveHour,
                    window: quotaWindow(model?.fiveHour),
                    provider: .claudeCode,
                    valueMode: valueMode,
                    unavailableText: "Unavailable"
                )
            }
            SettingsSectionRow {
                AgentQuotaWindowRow(
                    kind: .weekly,
                    window: quotaWindow(model?.sevenDay),
                    provider: .claudeCode,
                    valueMode: valueMode,
                    unavailableText: "Unavailable"
                )
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription(ClaudeUsageDisplayModel.weeklyScopeCaveat)
            }
        }

        if let extra = model?.extraUsage {
            SettingsSection("Extra usage") {
                SettingsSectionRow {
                    SettingsPreferenceControlRow("Pay-as-you-go") {
                        Text(extra.isEnabled ? "On" : "Off")
                    }
                }
                if extra.isEnabled {
                    SettingsSectionRow {
                        SettingsPreferenceControlRow("Spent this month") {
                            Text(extra.summaryText).monospacedDigit()
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsDescription(
                        extra.limitText == nil
                            ? "Amount billed beyond your plan. Anthropic did not report a monthly cap for this account."
                            : "Amount billed beyond your plan, against your monthly cap."
                    )
                }
            }
        }

        SettingsSection("Source") {
            SettingsSectionRow {
                SettingsPreferenceControlRow("Read from") {
                    Text(model.map { "\($0.sourceLabel) · \($0.capturedAtText)" } ?? "Not available")
                }
            }
            if let notice = model?.stalenessNotice {
                SettingsSectionRow {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SettingsSectionRow(showsDivider: false) {
                Button("Refresh Claude usage", action: refresh)
            }
        }
    }

    /// Prefers the plan proven by the connection; falls back to the plan hint
    /// carried on the usage snapshot.
    private var planName: String? {
        if case .connected(let account) = connectionState, let plan = account.planType {
            return plan.capitalized
        }
        return model?.planText
    }

    /// Maps Claude's window into the provider-neutral row type. A window that
    /// has already reset is dropped rather than shown as a current figure.
    private func quotaWindow(_ window: ClaudeUsageDisplayModel.Window?) -> QuotaWindow? {
        guard let window, !window.hasReset else { return nil }
        let used = Int(window.usedText.replacingOccurrences(of: "%", with: "")) ?? 0
        return QuotaWindow(usedPercent: used, resetAt: window.resetsAt, durationMinutes: nil)
    }

    @ViewBuilder
    private var connectionGuidance: some View {
        switch connectionState {
        case .checking:
            SettingsDescription("Checking the Claude connection…")
        case .missingCLI:
            SettingsDescription("Browser sign-in needs the Claude CLI. Use Claude Code credentials instead.")
        case .notConnected:
            SettingsDescription("Connect Claude to show current five-hour and weekly usage.")
        case .signingIn(let method):
            SettingsDescription("Signing in with \(method.displayName)…")
        case .connected:
            SettingsDescription("Claude is connected. Usage is read on a background schedule and never prompts.")
        case .failed(let failure):
            Text(failure.displayMessage)
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var connectionActions: some View {
        if showsConnectAction {
            Button("Use Claude Code credentials…", action: connectWithCredentials)
                .disabled(isSigningIn)
            SettingsDescription(ClaudeSignInPresentation.keychainDisclosure)
        }
        if case .connected = connectionState {
            Button("Disconnect", action: disconnect)
        }
    }

    private var showsConnectAction: Bool {
        switch connectionState {
        case .notConnected, .failed, .signingIn, .missingCLI: true
        case .checking, .connected: false
        }
    }

    private var isSigningIn: Bool {
        if case .signingIn = connectionState { return true }
        return false
    }
}
