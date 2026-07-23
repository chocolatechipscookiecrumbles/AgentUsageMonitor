import SwiftUI

struct MenuBarStatusLabel: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        MenuBarLabelView(
            presentation: MenuBarLabelPresentation(
                displayState: viewModel.displayState,
                providerSummaries: [
                    .codex(displayState: viewModel.displayState),
                    .claude(usageState: viewModel.claudeState),
                ],
                style: settings.menuBarDisplayStyle,
                valueMode: settings.quotaValueMode
            )
        )
    }
}
