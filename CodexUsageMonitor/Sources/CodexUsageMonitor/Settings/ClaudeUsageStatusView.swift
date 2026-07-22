import SwiftUI

/// Real, read-only Claude usage — replaces the static preview. Renders only
/// what the monitor actually read: an unavailable state says so explicitly
/// rather than showing zeros (capability gate #5), and any non-live result is
/// visibly labelled as such (probe plan §7/§9).
struct ClaudeUsageStatusView: View {
    let state: ClaudeUsageState
    let signInMethod: ClaudeSignInMethod?
    let refresh: () -> Void
    let useClaudeCodeCredentials: () -> Void

    private var model: ClaudeUsageDisplayModel? {
        state.presentation.map { ClaudeUsageDisplayModel(presentation: $0) }
    }

    var body: some View {
        if let model {
            availableBody(model)
        } else {
            unavailableBody
        }
    }

    @ViewBuilder
    private func availableBody(_ model: ClaudeUsageDisplayModel) -> some View {
        SettingsSection("Claude Code") {
            if let plan = model.planText {
                SettingsSectionRow {
                    SettingsLabeledRow("Plan") { Text(plan) }
                }
            }

            SettingsSectionRow {
                SettingsLabeledRow("Five-hour limit") {
                    windowValue(model.fiveHour)
                }
            }

            SettingsSectionRow {
                SettingsLabeledRow("Weekly limit") {
                    windowValue(model.sevenDay)
                }
            }

            SettingsSectionRow(showsDivider: false) {
                SettingsDescription(ClaudeUsageDisplayModel.weeklyScopeCaveat)
            }
        }

        SettingsSection("Source") {
            SettingsSectionRow {
                SettingsLabeledRow("Read from") {
                    Text("\(model.sourceLabel) · \(model.capturedAtText)")
                }
            }
            if let notice = model.stalenessNotice {
                SettingsSectionRow {
                    SettingsDescription(notice)
                }
            }
            SettingsSectionRow(showsDivider: false) {
                Button("Refresh Claude usage", action: refresh)
            }
        }
    }

    /// A missing window renders as "not available", never 0%.
    @ViewBuilder
    private func windowValue(_ window: ClaudeUsageDisplayModel.Window?) -> some View {
        if let window {
            VStack(alignment: .trailing, spacing: 2) {
                Text(window.usedText)
                if let note = window.resetNote {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                } else if let resetsAt = window.resetsAt {
                    Text("resets \(resetsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("not available").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var unavailableBody: some View {
        SettingsSection("Claude Code") {
            SettingsSectionRow {
                SettingsLabeledRow("Status") { Text("Not connected") }
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription(unavailableReason)
            }
        }

        SettingsSection("Connect") {
            SettingsSectionRow {
                Button("Use Claude Code credentials…", action: useClaudeCodeCredentials)
            }
            SettingsSectionRow(showsDivider: false) {
                SettingsDescription(ClaudeSignInPresentation.keychainDisclosure)
            }
        }
    }

    private var unavailableReason: String {
        if case .unavailable(let reason) = state { return reason }
        return ClaudeUsageState.notConnectedReason
    }
}
