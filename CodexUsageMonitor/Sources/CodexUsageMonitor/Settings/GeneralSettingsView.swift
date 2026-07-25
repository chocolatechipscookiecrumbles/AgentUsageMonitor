import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    /// The provider selector only applies to single-provider (non-graphical)
    /// styles, and only when more than one provider is connected.
    private var showsProviderSelector: Bool {
        settings.menuBarDisplayStyle.isSingleProvider
            && MenuBarProviderSelection.showsSelector(eligible: viewModel.menuBarEligibleProviders)
    }

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
                        // A menu (dropdown) rather than a segmented control:
                        // text and graphical options no longer fit a
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

                if showsProviderSelector {
                    SettingsSectionRow {
                        SettingsPreferenceControlRow(
                            "Provider",
                            description: "Which connected agent this style shows in the menu bar."
                        ) {
                            Picker("Provider", selection: $settings.menuBarProvider) {
                                ForEach(viewModel.menuBarEligibleProviders) { provider in
                                    Text(provider.tabTitle).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
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
