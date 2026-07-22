import SwiftUI
import Darwin

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
            MenuBarStatusLabel(viewModel: viewModel)
        }
        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
