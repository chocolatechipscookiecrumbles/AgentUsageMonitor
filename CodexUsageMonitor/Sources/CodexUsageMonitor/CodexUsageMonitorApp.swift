import SwiftUI
import Darwin
import UserNotifications

@main
@MainActor
struct CodexUsageMonitorApp: App {
    @StateObject private var viewModel = QuotaViewModel()

    init() {
        if CommandLine.arguments.contains(ClaudeUsageProbeCommand.flag) {
            Task {
                await ClaudeUsageProbeCommand.run()
                exit(0)
            }
            return
        }
        if CommandLine.arguments.contains("--live-read-once") {
            Task {
                let record = await QuotaRepository().refresh()
                let presentation = record.presentation
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(presentation), let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
                exit(0)
            }
            return
        }

        // Normal launch: banner every notification even when the app is
        // frontmost. Gated to the real `.app` bundle like the notifiers, so
        // command-line runs never touch the notification center.
        if Bundle.main.bundleURL.pathExtension == "app" {
            UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(MenuPopoverViabilityGate.isEnabled)) {
            WindowPopoverGateView()
        } label: {
            MenuBarStatusLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(!MenuPopoverViabilityGate.isEnabled)) {
            MenuBarPopoverView(viewModel: viewModel)
        } label: {
            MenuBarStatusLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
