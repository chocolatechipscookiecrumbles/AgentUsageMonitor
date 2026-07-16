import AppKit
import SwiftUI

@MainActor
final class SystemAppearanceObserver: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme

    private var observation: NSKeyValueObservation?

    init(application: NSApplication = .shared) {
        colorScheme = Self.colorScheme(for: application.effectiveAppearance)
        observation = application.observe(\.effectiveAppearance, options: [.new]) {
            [weak self] _, change in
            guard let appearance = change.newValue else { return }
            let colorScheme = Self.colorScheme(for: appearance)

            // AppKit changes NSApplication appearance on its main-thread UI boundary.
            MainActor.assumeIsolated {
                self?.colorScheme = colorScheme
            }
        }
    }

    private nonisolated static func colorScheme(for appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}
