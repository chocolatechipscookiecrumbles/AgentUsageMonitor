import AppKit
import SwiftUI

struct QuotaMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        Group {
            if viewModel.connectionState.isConnected {
                ConnectedQuotaMenuView(viewModel: viewModel)
            } else {
                CodexDisconnectedMenuView(
                    state: viewModel.connectionState,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI
                )
            }
            Divider()
            Button("Settings…", action: openNotificationSettings)
            Button("Quit Codex Usage Monitor") { NSApplication.shared.terminate(nil) }
        }
    }

    private func openNotificationSettings() {
        SettingsDestinationSelection.select(.notifications, in: viewModel.settings)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

}
