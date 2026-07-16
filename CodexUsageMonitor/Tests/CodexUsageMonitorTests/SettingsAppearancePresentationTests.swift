import AppKit
import SwiftUI
import XCTest
@testable import CodexUsageMonitor

@MainActor
final class SettingsAppearancePresentationTests: XCTestCase {
    func test_systemUsesCurrentApplicationColorScheme() {
        XCTAssertEqual(
            AppearancePreference.system.presentationColorScheme(system: .dark),
            .dark
        )
        XCTAssertEqual(
            AppearancePreference.system.presentationColorScheme(system: .light),
            .light
        )
    }

    func test_explicitPreferencesIgnoreCurrentApplicationColorScheme() {
        XCTAssertEqual(
            AppearancePreference.light.presentationColorScheme(system: .dark),
            .light
        )
        XCTAssertEqual(
            AppearancePreference.dark.presentationColorScheme(system: .light),
            .dark
        )
    }

    func test_systemAppearanceObserverTracksApplicationAppearanceChanges() {
        let application = NSApplication.shared
        let originalAppearance = application.appearance
        application.appearance = NSAppearance(named: .darkAqua)
        defer { application.appearance = originalAppearance }

        let observer = SystemAppearanceObserver(application: application)
        XCTAssertEqual(observer.colorScheme, .dark)

        application.appearance = NSAppearance(named: .aqua)
        drainMainRunLoop()
        XCTAssertEqual(observer.colorScheme, .light)

        application.appearance = NSAppearance(named: .darkAqua)
        drainMainRunLoop()
        XCTAssertEqual(observer.colorScheme, .dark)
    }

    private func drainMainRunLoop() {
        for _ in 0..<4 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
