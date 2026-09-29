import Foundation

/// Which window presents the menu. Normal launches keep the accepted
/// `MenuBarExtra` host until the content-fitted panel passes signed-app
/// acceptance (ADR 0004).
enum MenuHost: Equatable {
    case menuBarExtra
    case panel

    static let usage = "Use --menu-presentation=panel [--menu-fixture]"

    /// From `--menu-presentation=` or the signed trial app's Info.plist.
    static var requestedValue: String? {
        CommandLine.arguments.first { $0.hasPrefix("--menu-presentation=") }?
            .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).last.map(String.init)
            ?? Bundle.main.object(forInfoDictionaryKey: "MenuPresentationTrialMode") as? String
    }

    static var current: Self {
        requestedValue == "panel" ? .panel : .menuBarExtra
    }

    /// Synthetic replay; valid only with the panel.
    static var usesFixtures: Bool {
        CommandLine.arguments.contains("--menu-fixture")
            || Bundle.main.object(forInfoDictionaryKey: "MenuPresentationFixtures") as? Bool == true
    }

    /// An unknown presentation, or fixtures without the panel, is a usage error.
    static var isInvalidRequest: Bool {
        (requestedValue != nil && current != .panel) || (usesFixtures && current != .panel)
    }
}
