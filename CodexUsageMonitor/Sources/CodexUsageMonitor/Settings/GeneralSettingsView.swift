import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let status: SettingsStatus
    let displayState: QuotaDisplayState

    var body: some View {
        SettingsPage {
            SettingsSection("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .disabled(!launchAtLogin.canChange)
                if let guidanceMessage = launchAtLogin.guidanceMessage {
                    Text(guidanceMessage)
                        .font(.callout)
                        .foregroundStyle(launchAtLogin.errorMessage == nil ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if launchAtLogin.showsSystemSettingsButton {
                    Button("Open Login Items…", action: launchAtLogin.openSystemSettings)
                }
            }

            SettingsSection("Appearance") {
                SettingsLabeledRow("App appearance") {
                    Picker("App appearance", selection: $settings.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .labelsHidden()
                    .frame(width: SettingsLayoutMetrics.controlWidth)
                }
            }

            SettingsSection("Keyboard Shortcuts") {
                Toggle("Enable keyboard shortcuts", isOn: $settings.keyboardShortcutsEnabled)
                SettingsDescription("Allows app shortcuts such as ⌘R for Refresh now.")
                    .padding(.leading, 26)
            }

            SettingsSection("Menu Bar") {
                SettingsLabeledRow("Appearance") {
                    Picker("Appearance", selection: $settings.menuBarDisplayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: SettingsLayoutMetrics.controlWidth)
                }

                SettingsLabeledRow("Show") {
                    Picker("Show", selection: $settings.quotaValueMode) {
                        ForEach(QuotaValueMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: SettingsLayoutMetrics.controlWidth)
                }

                SettingsLabeledRow("Preview") {
                    MenuBarLabelView(
                        presentation: MenuBarLabelPresentation(
                            displayState: displayState,
                            style: settings.menuBarDisplayStyle,
                            valueMode: settings.quotaValueMode
                        )
                    )
                }

                SettingsDescription("Updates after each quota refresh using the frequency selected in Refresh.")
                    .settingsValueColumnAligned()
            }

            SettingsSection("Application") {
                SettingsLabeledRow("Name") { Text("Codex Usage Monitor") }
                SettingsLabeledRow("Version") { Text(status.appVersion) }
                SettingsLabeledRow("Build") { Text(status.buildNumber) }
            }

            SettingsSection("Current Scope") {
                SettingsLabeledRow("Provider") { Text("OpenAI Codex") }
                SettingsDescription("The daily-driver roadmap remains Codex-first. Additional providers are not active in this build.")
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
