import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        SettingsPage {
            SettingsSection("Startup & Shortcuts") {
                SettingsSectionRow {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsPreferenceToggle(
                            "Launch at login",
                            description: launchAtLogin.guidanceMessage,
                            descriptionColor: launchAtLogin.errorMessage == nil ? .secondary : .orange,
                            isOn: launchAtLoginBinding
                        )
                            .disabled(!launchAtLogin.canChange)
                        if launchAtLogin.showsSystemSettingsButton {
                            Button("Open Login Items…", action: launchAtLogin.openSystemSettings)
                        }
                    }
                }
                SettingsSectionRow(showsDivider: false) {
                    SettingsPreferenceToggle(
                        "Enable keyboard shortcuts",
                        description: "Allows app shortcuts such as ⌘R for Refresh now.",
                        isOn: $settings.keyboardShortcutsEnabled
                    )
                }
            }

            SettingsSection("Menu Bar Icon") {
                SettingsSectionRow {
                    SettingsPreferenceControlRow("Style") {
                        // A menu (dropdown) rather than a segmented control: four
                        // options (two text, two graphical) no longer fit a
                        // segmented control at the compact width. A dedicated
                        // display-mode destination is deferred.
                        Picker("Style", selection: $settings.menuBarDisplayStyle) {
                            ForEach(MenuBarDisplayStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                }

                SettingsSectionRow {
                    SettingsPreferenceControlRow(
                        "Show",
                        description: "Updates after each quota refresh using the frequency selected in Refresh."
                    ) {
                        Picker("Show", selection: $settings.quotaValueMode) {
                            ForEach(QuotaValueMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: SettingsLayoutMetrics.compactSegmentedControlWidth)
                    }
                }

                SettingsSectionRow {
                    SettingsPreferenceControlRow(
                        "Appearance",
                        description: "Controls the Settings window appearance. The menu bar follows macOS."
                    ) {
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
                }

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
