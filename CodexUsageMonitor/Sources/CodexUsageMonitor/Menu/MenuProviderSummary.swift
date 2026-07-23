import Foundation

/// The compact provider state used to choose the single quota value shown in
/// the menu bar. Availability is explicit so a missing read can never be
/// mistaken for zero utilization.
struct MenuProviderSummary: Equatable {
    enum Freshness: Equatable {
        case confirmed
        case cached
        case passive

        var accessibilityName: String {
            switch self {
            case .confirmed: "confirmed"
            case .cached: "cached"
            case .passive: "passive"
            }
        }

        var isConfirmed: Bool {
            self == .confirmed
        }
    }

    enum Availability: Equatable {
        case available(usedPercent: Int, freshness: Freshness)
        case unavailable
    }

    let provider: AgentProvider
    let availability: Availability

    var usedPercent: Int? {
        guard case .available(let usedPercent, _) = availability else { return nil }
        return usedPercent
    }

    var freshness: Freshness? {
        guard case .available(_, let freshness) = availability else { return nil }
        return freshness
    }

    init(provider: AgentProvider, usedPercent: Int?, freshness: Freshness?) {
        self.provider = provider
        if let usedPercent, let freshness {
            availability = .available(
                usedPercent: min(max(usedPercent, 0), 100),
                freshness: freshness
            )
        } else {
            availability = .unavailable
        }
    }

    static func codex(displayState: QuotaDisplayState) -> Self {
        let presentation = displayState.displayedRecord?.presentation
        return Self(
            provider: .codex,
            usedPercent: highestUtilization(
                presentation?.fiveHour?.usedPercent,
                presentation?.weekly?.usedPercent
            ),
            freshness: displayState.mode == .confirmedCompleted ? .confirmed : .cached
        )
    }

    static func claude(usageState: ClaudeUsageState) -> Self {
        guard let presentation = usageState.presentation else {
            return Self(provider: .claudeCode, usedPercent: nil, freshness: nil)
        }
        let model = ClaudeUsageDisplayModel(presentation: presentation)
        return Self(
            provider: .claudeCode,
            usedPercent: highestUtilization(
                model.fiveHour?.usedPercent,
                model.sevenDay?.usedPercent
            ),
            freshness: freshness(for: presentation.delivery)
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

    private static func freshness(for delivery: ClaudeUsageDelivery) -> Freshness {
        switch delivery {
        case .live: .confirmed
        case .cached: .cached
        case .passiveSnapshot: .passive
        }
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
