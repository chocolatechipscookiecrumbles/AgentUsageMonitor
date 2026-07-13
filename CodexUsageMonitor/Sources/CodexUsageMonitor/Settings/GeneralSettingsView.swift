import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let status: SettingsStatus
    let displayState: QuotaDisplayState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .disabled(!launchAtLogin.canChange)
                if let guidanceMessage = launchAtLogin.guidanceMessage {
                    Text(guidanceMessage)
                        .foregroundStyle(launchAtLogin.errorMessage == nil ? Color.secondary : Color.orange)
                }
                if launchAtLogin.showsSystemSettingsButton {
                    Button("Open Login Items…", action: launchAtLogin.openSystemSettings)
                }
            }

            Section("Appearance") {
                Picker("App appearance", selection: $settings.appearancePreference) {
                    ForEach(AppearancePreference.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }

            Section("Keyboard Shortcuts") {
                Toggle("Enable keyboard shortcuts", isOn: $settings.keyboardShortcutsEnabled)
                Text("Allows app shortcuts such as ⌘R for Refresh now.")
                    .foregroundStyle(.secondary)
            }

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
        .onAppear(perform: launchAtLogin.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }
}
