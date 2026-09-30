import Foundation

/// Which window presents the menu. The content-fitted panel is the default
/// (ADR 0004); the stable-host `MenuBarExtra` menu remains as a kill switch.
enum MenuHost: Equatable {
    case menuBarExtra
    case panel

    static let usage = "Use --menu-host=legacy, or --menu-presentation=panel [--menu-fixture]"
    static let legacyArgument = "--menu-host=legacy"
    /// Set with `defaults write com.david.codex-usage-monitor MenuHostLegacy -bool true`.
    static let legacyDefaultsKey = "MenuHostLegacy"

    /// From `--menu-presentation=` or the signed test app's Info.plist.
    static var requestedValue: String? {
        CommandLine.arguments.first { $0.hasPrefix("--menu-presentation=") }?
            .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).last.map(String.init)
            ?? Bundle.main.object(forInfoDictionaryKey: "MenuPresentationTrialMode") as? String
    }

    static var current: Self {
        let legacy = CommandLine.arguments.contains(legacyArgument)
            || UserDefaults.standard.bool(forKey: legacyDefaultsKey)
        return legacy && !usesFixtures ? .menuBarExtra : .panel
    }

    /// Synthetic replay; runs in the panel.
    static var usesFixtures: Bool {
        CommandLine.arguments.contains("--menu-fixture")
            || Bundle.main.object(forInfoDictionaryKey: "MenuPresentationFixtures") as? Bool == true
    }

    /// Only `panel` is a valid presentation request.
    static var isInvalidRequest: Bool {
        requestedValue.map { $0 != "panel" } ?? false
    }
}
