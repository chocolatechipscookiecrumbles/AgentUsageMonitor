import Foundation

/// The compact provider state used to choose the single quota value shown in
/// the menu bar. Availability is explicit so a missing read can never be
/// mistaken for zero utilization.
struct MenuProviderSummary: Equatable {
    enum Availability: Equatable {
        case available(usedPercent: Int)
        case unavailable
    }

    let provider: AgentProvider
    let availability: Availability

    var usedPercent: Int? {
        guard case .available(let usedPercent) = availability else { return nil }
        return usedPercent
    }

    init(provider: AgentProvider, usedPercent: Int?) {
        self.provider = provider
        availability = usedPercent.map {
            .available(usedPercent: min(max($0, 0), 100))
        } ?? .unavailable
    }

    static func codex(displayState: QuotaDisplayState) -> Self {
        let presentation = displayState.displayedRecord?.presentation
        return Self(
            provider: .codex,
            usedPercent: highestUtilization(
                presentation?.fiveHour?.usedPercent,
                presentation?.weekly?.usedPercent
            )
        )
    }

    static func claude(usageState: ClaudeUsageState) -> Self {
        let model = usageState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) }
        return Self(
            provider: .claudeCode,
            usedPercent: highestUtilization(
                model?.fiveHour?.usedPercent,
                model?.sevenDay?.usedPercent
            )
        )
    }

    static func mostAtRisk(in summaries: [Self]) -> Self? {
        var selection: Self?

        for summary in summaries.sorted(by: providerPrecedes) {
            guard let candidatePercent = summary.usedPercent else { continue }
            guard let selectedPercent = selection?.usedPercent else {
                selection = summary
                continue
            }
            if candidatePercent > selectedPercent {
                selection = summary
            }
        }

        return selection
    }

    func visiblePercent(for mode: QuotaValueMode) -> Int? {
        guard let usedPercent else { return nil }
        return switch mode {
        case .used: usedPercent
        case .remaining: 100 - usedPercent
        }
    }

    private static func highestUtilization(_ values: Int?...) -> Int? {
        values.compactMap { $0 }.max()
    }

    private static func providerPrecedes(_ lhs: Self, _ rhs: Self) -> Bool {
        providerOrder(lhs.provider) < providerOrder(rhs.provider)
    }

    private static func providerOrder(_ provider: AgentProvider) -> Int {
        switch provider {
        case .codex: 0
        case .claudeCode: 1
        case .githubCopilot: 2
        }
    }
}
