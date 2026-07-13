import SwiftUI
import Darwin

@main
@MainActor
struct CodexUsageMonitorApp: App {
    @State private var viewModel = QuotaViewModel()

    init() {
        guard CommandLine.arguments.contains("--live-read-once") else { return }
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
    }

    var body: some Scene {
        MenuBarExtra {
            QuotaMenuView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarTitle, systemImage: "gauge.with.dots.needle.33percent")
        }
        Settings {
            SettingsView(
                settings: viewModel.settings,
                setAlertsEnabled: viewModel.setAlertsEnabled,
                openNotificationSettings: viewModel.openNotificationSettings
            )
        }
    }
}
