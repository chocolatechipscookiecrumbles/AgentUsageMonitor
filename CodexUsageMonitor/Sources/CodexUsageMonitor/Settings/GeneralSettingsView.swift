import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        SettingsPage {
            SettingsSection("Startup") {
                SettingsPreferenceToggle("Launch at login", isOn: launchAtLoginBinding)
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

            SettingsSection("Keyboard Shortcuts") {
                SettingsPreferenceToggle(
                    "Enable keyboard shortcuts",
                    description: "Allows app shortcuts such as ⌘R for Refresh now.",
                    isOn: $settings.keyboardShortcutsEnabled
                )
            }

            SettingsSection("Menu Bar Icon") {
                SettingsLabeledRow("Style") {
                    Picker("Style", selection: $settings.menuBarDisplayStyle) {
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

                SettingsLabeledRow("Appearance") {
                    Picker("Appearance", selection: $settings.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: SettingsLayoutMetrics.appearanceSegmentedControlWidth)
                    .accessibilityLabel("Appearance")
                }

                SettingsDescription("Controls the Settings window appearance. The menu bar follows macOS.")
                    .settingsValueColumnAligned()

                SettingsDescription("Updates after each quota refresh using the frequency selected in Refresh.")
                    .settingsValueColumnAligned()
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
