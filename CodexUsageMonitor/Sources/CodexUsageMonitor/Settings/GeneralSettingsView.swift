import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    let status: SettingsStatus
    let displayState: QuotaDisplayState

    var body: some View {
        Form {
            Section("Menu Bar") {
                Picker("Appearance", selection: $settings.menuBarDisplayStyle) {
                    ForEach(MenuBarDisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Picker("Show", selection: $settings.quotaValueMode) {
                    ForEach(QuotaValueMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                LabeledContent("Preview") {
                    MenuBarLabelView(
                        presentation: MenuBarLabelPresentation(
                            displayState: displayState,
                            style: settings.menuBarDisplayStyle,
                            valueMode: settings.quotaValueMode
                        )
                    )
                }

                Text("Updates after each quota refresh using the frequency selected in Refresh.")
                    .foregroundStyle(.secondary)
            }

            Section("Application") {
                LabeledContent("Name", value: "Codex Usage Monitor")
                LabeledContent("Version", value: status.appVersion)
                LabeledContent("Build", value: status.buildNumber)
            }

            Section("Current scope") {
                LabeledContent("Provider", value: "OpenAI Codex")
                Text("The daily-driver roadmap remains Codex-first. Additional providers are not active in this build.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
