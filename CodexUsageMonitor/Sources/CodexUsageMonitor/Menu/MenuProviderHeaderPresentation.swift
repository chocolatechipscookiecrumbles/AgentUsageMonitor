import Foundation

struct MenuProviderHeaderPresentation {
    let title: String
    let subtitle: String
    let status: MenuPopoverStatus

    static func codex(
        displayState: QuotaDisplayState,
        isRefreshing: Bool
    ) -> Self {
        if isRefreshing {
            return Self(
                title: "Codex Usage Monitor",
                subtitle: "Refreshing…",
                status: .refreshing
            )
        }

        guard let presentation = displayState.displayedRecord?.presentation else {
            return Self(
                title: "Codex Usage Monitor",
                subtitle: "Usage unavailable",
                status: .unavailable
            )
        }

        return Self(
            title: "Codex Usage Monitor",
            subtitle: updatedText(for: presentation.collectedAt),
            status: displayState.mode == .confirmedCompleted ? .confirmed : .cached
        )
    }

    static func claude(
        usageState: ClaudeUsageState,
        isRefreshing: Bool
    ) -> Self {
        if isRefreshing {
            return Self(
                title: "Claude Usage Monitor",
                subtitle: "Refreshing…",
                status: .refreshing
            )
        }

        guard let presentation = usageState.presentation else {
            return Self(
                title: "Claude Usage Monitor",
                subtitle: "Usage unavailable",
                status: .unavailable
            )
        }

        return Self(
            title: "Claude Usage Monitor",
            subtitle: updatedText(for: presentation.snapshot.capturedAt),
            status: presentation.delivery == .live ? .confirmed : .cached
        )
    }

    private static func updatedText(for date: Date) -> String {
        "Updated \(date.formatted(date: .omitted, time: .standard))"
    }
}
