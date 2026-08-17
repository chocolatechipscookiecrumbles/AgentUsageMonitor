import SwiftUI

/// Claude's Settings page, built on the same template as
/// `CodexAgentSettingsView`: a Connection section (status, plan, guidance,
/// actions) followed by the provider-neutral quota rows, so both agents read
/// as one system.
///
/// It uses the shared `AgentQuotaSessionSection`, passing a "used" credits
/// label (Anthropic reports spend, not a balance) and no reset credits.
struct ClaudeAgentSettingsView: View {
    @ObservedObject var settings: AppSettings
    let setupState: ClaudeSetupState
    let connectionState: ClaudeConnectionState
    let usageState: ClaudeUsageState
    let valueMode: QuotaValueMode
    let connectWithCredentials: () -> Void
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
        if setupState == .notSetUp {
            ClaudeSetupOnboardingView(connect: connectWithCredentials)
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
                SettingsValueRow("Status", value: status(model).text, description: status(model).detail)
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
                isConnected: status(model).isConnected,
                hasFiveHourWindow: model?.fiveHour != nil
            ) ? ClaudeUsageDisplayModel.fiveHourSessionNote : nil
        )

        SettingsSection("Source") {
            SettingsSectionRow {
                // The longest value on the page ("Cached Claude OAuth result ·
                // 3 hours ago"), and the staleness note explains this row, so
                // it rides as its description instead of a block of its own.
                SettingsValueRow(
                    "Read from",
                    value: model.map { "\($0.sourceLabel) · \($0.capturedAtText)" } ?? "Not available",
                    description: model?.stalenessNotice
                )
            }
            SettingsSectionRow {
                SettingsPreferenceControlRow(
                    "Refresh now",
                    description: "Uses the free sources. Never prompts."
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
                    "Claude CLI check",
                    description: ClaudeCLIUsageProbe.buttonFootnote
                ) {
                    Button(isRunningCLIProbe ? "Reading…" : "Run check") {
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

    /// The same derivation the context rail uses, so a live read is reported
    /// as connected on both surfaces even if the sign-in button was never
    /// pressed.
    private func status(_ model: ClaudeUsageDisplayModel?) -> ClaudeConnectionStatus {
        ClaudeConnectionStatus.resolve(signInState: connectionState, usageState: usageState)
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
        if showsConnectAction {
            // Disclosure sits with the button that triggers the prompt, rather
            // than as a separate full-width block.
            SettingsPreferenceControlRow(
                "Claude Code credentials",
                description: ClaudeSignInPresentation.keychainDisclosure
            ) {
                Button("Connect", action: connectWithCredentials)
                    .disabled(isSigningIn)
            }
            // The Always Allow / Allow explanation belongs before connecting,
            // so the user understands the Keychain prompt they will approve.
            SettingsDescription(ClaudeSignInPresentation.keychainPromptExplanation)
        }
        if isEffectivelyConnected {
            SettingsPreferenceControlRow("Connected account") {
                AgentDisconnectButton(provider: .claudeCode, disconnect: disconnect)
            }
        }
    }

    /// A live read (passive capture with a working credential) or an explicit
    /// sign-in both count as connected here, matching the status row.
    private var isEffectivelyConnected: Bool {
        ClaudeConnectionStatus.isEffectivelyConnected(
            signInState: connectionState,
            usageState: usageState
        )
    }

    private var showsConnectAction: Bool {
        if isEffectivelyConnected { return false }
        switch connectionState {
        case .notConnected, .failed, .signingIn, .missingCLI: return true
        case .checking, .connected: return false
        }
    }

    private var isSigningIn: Bool {
        if case .signingIn = connectionState { return true }
        return false
    }
}
