import SwiftUI
import Darwin
import UserNotifications

@MainActor
struct CodexUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate

    /// The composition root owns the model; the scenes read the same instance
    /// the startup tour was given.
    private var viewModel: QuotaViewModel { appDelegate.viewModel }

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
        if Bundle.main.bundleURL.pathExtension == "app", !MenuHost.usesFixtures {
            UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(MenuHost.current == .menuBarExtra && MenuPopoverViabilityGate.isEnabled)) {
            WindowPopoverGateView()
        } label: {
            if !MenuHost.usesFixtures {
                MenuBarStatusLabel(viewModel: viewModel)
            }
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(MenuHost.current == .menuBarExtra && !MenuPopoverViabilityGate.isEnabled)) {
            if !MenuHost.usesFixtures {
                MenuBarPopoverView(viewModel: viewModel)
            }
        } label: {
            if !MenuHost.usesFixtures {
                MenuBarStatusLabel(viewModel: viewModel)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            if MenuHost.usesFixtures {
                Text("Settings are unavailable in the synthetic menu demo.")
            } else {
                SettingsView(viewModel: viewModel)
            }
        }
    }
}
