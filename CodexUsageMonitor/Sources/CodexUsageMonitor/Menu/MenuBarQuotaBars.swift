import Foundation

/// Per-provider, two-window **remaining** data for the graphical menu-bar modes
/// (`.stackedBars` / `.combinedBars`). Each window is either a normalized
/// remaining value in `0...1` or `unavailable`, so an absent reading is never
/// drawn as an empty (0%) bar. This is the pure, testable core; the SwiftUI
/// renderer maps it to bar widths.
struct MenuBarQuotaBars: Equatable {
    enum Fill: Equatable {
        /// Normalized remaining quota, clamped to `0...1`.
        case value(Double)
        case unavailable

        var normalizedRemaining: Double? {
            guard case .value(let v) = self else { return nil }
            return v
        }
    }

    let provider: AgentProvider
    let fiveHour: Fill
    let weekly: Fill
    /// `nil` when the provider has no eligible reading at all.
    let freshness: MenuProviderSummary.Freshness?

    var hasAnyValue: Bool {
        fiveHour.normalizedRemaining != nil || weekly.normalizedRemaining != nil
    }

    init(
        provider: AgentProvider,
        fiveHourRemaining: Int?,
        weeklyRemaining: Int?,
        freshness: MenuProviderSummary.Freshness?
    ) {
        self.provider = provider
        self.fiveHour = Self.fill(fiveHourRemaining)
        self.weekly = Self.fill(weeklyRemaining)
        // Freshness is only meaningful when there is something to be fresh about.
        let hasValue = fiveHourRemaining != nil || weeklyRemaining != nil
        self.freshness = hasValue ? freshness : nil
    }

    /// Clamps malformed values (below 0 / above 100) into a `0...1` fill; a
    /// missing window maps to `.unavailable`, distinct from `value(0)`.
    private static func fill(_ remainingPercent: Int?) -> Fill {
        guard let remainingPercent else { return .unavailable }
        let clamped = min(max(remainingPercent, 0), 100)
        return .value(Double(clamped) / 100)
    }

    // MARK: Builders (mirror MenuProviderSummary's per-provider mapping)

    static func codex(displayState: QuotaDisplayState) -> Self {
        let presentation = displayState.displayedRecord?.presentation
        return Self(
            provider: .codex,
            fiveHourRemaining: presentation?.fiveHour?.remainingPercent,
            weeklyRemaining: presentation?.weekly?.remainingPercent,
            freshness: displayState.mode == .confirmedCompleted ? .confirmed : .cached
        )
    }

    static func claude(usageState: ClaudeUsageState, now: Date = .now) -> Self {
        guard let presentation = usageState.presentation else {
            return Self(provider: .claudeCode, fiveHourRemaining: nil, weeklyRemaining: nil, freshness: nil)
        }
        let model = ClaudeUsageDisplayModel(presentation: presentation, now: now)
        return Self(
            provider: .claudeCode,
            fiveHourRemaining: Self.eligibleRemaining(model.fiveHour),
            weeklyRemaining: Self.eligibleRemaining(model.sevenDay),
            freshness: MenuProviderSummary.freshness(for: presentation.delivery)
        )
    }

    /// The configured providers in canonical order (Codex, then Claude). A
    /// provider with no data still appears, rendered as empty tracks, so the
    /// menu-bar block keeps a stable width and height.
    static func providers(
        codexDisplayState: QuotaDisplayState,
        claudeState: ClaudeUsageState,
        now: Date = .now
    ) -> [MenuBarQuotaBars] {
        [
            .codex(displayState: codexDisplayState),
            .claude(usageState: claudeState, now: now),
        ]
    }

    private static func eligibleRemaining(_ window: ClaudeUsageDisplayModel.Window?) -> Int? {
        guard let window, !window.hasReset else { return nil }
        return 100 - window.usedPercent
    }
}
