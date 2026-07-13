import SwiftUI

struct RefreshNowButton: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        if settings.keyboardShortcutsEnabled {
            Button(buttonTitle, action: viewModel.refresh)
                .disabled(viewModel.isRefreshing)
                .keyboardShortcut("r", modifiers: .command)
        } else {
            Button(buttonTitle, action: viewModel.refresh)
                .disabled(viewModel.isRefreshing)
        }
    }

    private var buttonTitle: String {
        viewModel.isRefreshing ? "Refreshing…" : "Refresh now"
    }
}
