import SwiftUI

/// Claude's Settings page, built on the same template as
/// `CodexAgentSettingsView`: a Connection section (status, plan, guidance,
/// actions) followed by the provider-neutral quota rows, so both agents read
/// as one system.
///
/// Spending remains distinct from prepaid balance and redeemable reset offers.
struct ClaudeAgentSettingsView: View {
    @ObservedObject var settings: AppSettings
    let isEnrolled: Bool
    let connectionState: ClaudeConnectionState
    let usageState: ClaudeUsageState
    let valueMode: QuotaValueMode
    let connect: () -> Void
    let disconnect: () -> Void
    let refresh: () -> Void
    let isRunningCLIProbe: Bool
    let cliProbeError: String?
    let hasConsentedToCLIProbe: Bool
    let setCLIProbeConsent: (Bool) -> Void
    let runCLIProbe: () -> Void
    let passiveCapture: ClaudePassiveCaptureHealth?
    let refreshPassiveCapture: () -> Void
    let configurePassiveCapture: (Bool) -> Void

    @State private var showCLIConsent = false
    @State private var pendingRepair: String?

    var body: some View {
        if !isEnrolled {
            ClaudeSetupOnboardingView(connect: connect)
        } else {
            // Built once per render: it does date math and currency formatting,
            // and a computed property would rebuild it at every reference.
            content(model: usageState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) })
        }
    }

    /// Passive capture: free, credential-free, and the only source that keeps
    /// working when the OAuth token expires or its Keychain grant lapses.
    @ViewBuilder
    private var passiveCaptureRow: some View {
        if let passiveCapture {
            SettingsPreferenceControlRow(
                "Passive capture",
                description: passiveCapture.summary
            ) {
                if let title = passiveCapture.repairActionTitle {
                    Button(title) {
                        if case .repairable(let existing, _) = passiveCapture.state {
                            pendingRepair = existing
                        } else {
                            configurePassiveCapture(false)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(model: ClaudeUsageDisplayModel?) -> some View {
        SettingsSection("Connection") {
            SettingsSectionRow {
                // Status text is variable-length ("Signing in with Claude Code
                // credentials…"), so it wraps rather than widening the card.
                SettingsValueRow("Status", value: connectionStatus.text, description: connectionStatus.detail)
            }
            if let plan = planName(model) {
                SettingsSectionRow {
                    SettingsValueRow("Plan", value: plan)
                }
            }
            SettingsSectionRow(showsDivider: false) {
                connectionActions
            }
        }

        AgentQuotaSessionSection(
            provider: .claudeCode,
            fiveHour: quotaWindow(model?.fiveHour),
            weekly: quotaWindow(model?.sevenDay),
            valueMode: valueMode,
            creditsLabel: ClaudeUsageDisplayModel.creditsUsedLabel,
            creditsDescription: ClaudeUsageDisplayModel.creditsUsedDescription,
            creditsValue: model?.creditsUsedText,
            resetCredits: nil,
            weeklyFootnote: ClaudeUsageDisplayModel.weeklyScopeCaveat,
            fiveHourNote: ClaudeUsageDisplayModel.showsFiveHourSessionNote(
                isConnected: usageState.presentation?.delivery == .live,
                hasFiveHourWindow: model?.fiveHour != nil
            ) ? ClaudeUsageDisplayModel.fiveHourSessionNote : nil
        )

        SettingsSection("Credits and resets") {
            SettingsSectionRow {
                SettingsValueRow("Available resets", value: "Unavailable")
            }
            SettingsSectionRow {
                SettingsValueRow("Credit balance", value: "Unavailable")
            }
            SettingsSectionRow {
                SettingsValueRow(
                    "Monthly spending limit", value: model?.monthlySpendingLimitText ?? "Unavailable",
                    description: "A spending cap, separate from your prepaid balance."
                )
            }
            if let updated = model?.financialUpdatedText {
                SettingsSectionRow {
                    SettingsValueRow(
                        "Last updated", value: updated,
                        description: "Last financial reading. Passive quota updates do not refresh it."
                    )
                }
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsPreferenceControlRow(
                    "Claude Usage", description: "Check your balance and available resets in Claude."
                ) {
                    Link("Open Claude Usage", destination: URL(string: "https://claude.ai/settings/usage")!)
                }
            }
        }

        SettingsSection("Source") {
            SettingsSectionRow {
                // The longest value on the page ("Cached Claude OAuth result ·
                // 3 hours ago"), and the staleness note explains this row, so
                // it rides as its description instead of a block of its own.
                SettingsValueRow(
                    "Read from",
                    value: model.map { "\($0.sourceLabel) · Last updated \($0.capturedAtText)" } ?? "Not available",
                    description: model?.stalenessNotice
                )
            }
            SettingsSectionRow {
                SettingsPreferenceControlRow(
                    "Refresh now",
                    description: "Uses passive capture, then silent live fallback. Never requests Keychain permission."
                ) {
                    Button("Refresh", action: refresh)
                }
            }
            SettingsSectionRow(showsDivider: false) {
                passiveCaptureRow
            }
        }
        .onAppear(perform: refreshPassiveCapture)
        .confirmationDialog(
            "Replace Claude Code's status line?",
            isPresented: Binding(
                get: { pendingRepair != nil },
                set: { if !$0 { pendingRepair = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                configurePassiveCapture(true)
                pendingRepair = nil
            }
            Button("Cancel", role: .cancel) { pendingRepair = nil }
        } message: {
            // The exact command being replaced is shown, because this edits the
            // user's own Claude Code configuration file.
            Text(pendingRepair.map { "Replaces:\n\($0)\n\nOnly the statusLine entry changes." } ?? "")
        }

        forceCLISection

        // Claude now has a real per-provider threshold store and notification
        // delivery, so its Remaining Quota chips are live like Codex's.
        AgentTokenMonitorSection(settings: settings, provider: .claudeCode)

        AgentUsageWarningsSection(settings: settings, provider: .claudeCode)
    }

    /// Tier 2 — deliberately separated from the free refresh above, with the
    /// cost stated before the user presses it and confirmed on first use.
    @ViewBuilder
    private var forceCLISection: some View {
        SettingsSection("Force a reading") {
            SettingsSectionRow(showsDivider: cliProbeError != nil) {
                // Title, cost footnote and button in one row rather than three.
                SettingsPreferenceControlRow(
                    "Claude /usage",
                    description: ClaudeCLIUsageProbe.buttonFootnote
                ) {
                    Button(isRunningCLIProbe ? "Reading…" : "Force Read") {
                        if hasConsentedToCLIProbe {
                            runCLIProbe()
                        } else {
                            showCLIConsent = true
                        }
                    }
                    .disabled(isRunningCLIProbe)
                }
            }
            if let cliProbeError {
                SettingsSectionRow(showsDivider: false) {
                    Text(cliProbeError)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .alert(ClaudeCLIUsageProbe.consentTitle, isPresented: $showCLIConsent) {
            Button("Cancel", role: .cancel) {}
            Button("Run the check") {
                setCLIProbeConsent(true)
                runCLIProbe()
            }
        } message: {
            Text(ClaudeCLIUsageProbe.consentMessage)
        }
    }

    /// The same derivation the context rail uses, so every Claude surface has
    /// one definition of monitoring enrollment and live fallback availability.
    private var connectionStatus: ClaudeConnectionStatus {
        ClaudeConnectionStatus.resolve(
            isEnrolled: isEnrolled,
            signInState: connectionState,
            usageState: usageState
        )
    }

    /// Prefers the plan proven by the connection; falls back to the plan hint
    /// carried on the usage snapshot.
    private func planName(_ model: ClaudeUsageDisplayModel?) -> String? {
        if let plan = AgentPlanName.display(connectionState.accountPlanType) {
            return plan
        }
        return model?.planText
    }

    /// Maps Claude's window into the provider-neutral row type. A window that
    /// has already reset is dropped rather than shown as a current figure.
    private func quotaWindow(_ window: ClaudeUsageDisplayModel.Window?) -> QuotaWindow? {
        guard let window, !window.hasReset else { return nil }
        return QuotaWindow(usedPercent: window.usedPercent, resetAt: window.resetsAt, durationMinutes: nil)
    }


    @ViewBuilder
    private var connectionActions: some View {
        SettingsPreferenceControlRow(
            "Live fallback",
            description: "Reconnect may ask for Keychain permission. Passive monitoring continues if access is unavailable."
        ) {
            Button("Reconnect Claude", action: connect)
                .disabled(isSigningIn)
        }
        SettingsPreferenceControlRow("Claude monitoring") {
            AgentDisconnectButton(provider: .claudeCode, disconnect: disconnect)
        }
    }

    private var isSigningIn: Bool {
        if case .connecting = connectionState { return true }
        return false
    }
}
