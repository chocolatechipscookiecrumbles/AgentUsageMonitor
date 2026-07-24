import SwiftUI

struct MenuBarStatusLabel: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        if settings.menuBarDisplayStyle.isGraphical {
            MenuBarBarsView(
                style: settings.menuBarDisplayStyle,
                providers: MenuBarQuotaBars.providers(
                    codexDisplayState: viewModel.displayState,
                    claudeState: viewModel.claudeState
                )
            )
        } else {
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
}
