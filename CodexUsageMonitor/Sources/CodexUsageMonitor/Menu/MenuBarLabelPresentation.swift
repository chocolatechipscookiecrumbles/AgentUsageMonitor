import Foundation

struct MenuBarLabelPresentation: Equatable, Sendable {
    let text: String
    let showsGauge: Bool
    let showsPauseMarker: Bool
    let providerAssetName: String?
    let accessibilityLabel: String

    /// The per-provider windows resolved for the text/single-provider styles.
    /// Both are expressed as *used* percentages so `QuotaValueMode` can render
    /// either convention; `nil` means the window has no eligible reading.
    private struct Reading {
        var fiveHourUsed: Int?
        var weeklyUsed: Int?
        var freshness: MenuProviderSummary.Freshness?
    }

    init(
        provider: AgentProvider,
        codexDisplayState: QuotaDisplayState,
        claudeState: ClaudeUsageState,
        style: MenuBarDisplayStyle,
        valueMode: QuotaValueMode,
        showsProviderMarker: Bool = false,
        now: Date = .now
    ) {
        let reading = Self.reading(
            for: provider,
            codexDisplayState: codexDisplayState,
            claudeState: claudeState,
            now: now
        )
        let fiveHourValue = reading.fiveHourUsed.map(valueMode.value(forUsedPercent:))
        let weeklyValue = reading.weeklyUsed.map(valueMode.value(forUsedPercent:))
        let freshness = (reading.freshness ?? .confirmed).accessibilityName

        showsGauge = false
        showsPauseMarker = provider == .codex && codexDisplayState.mode == .cachedPaused
        // Show the provider glyph only when the user actually has a choice, so a
        // single-provider setup keeps its clean text-only label. The menu-bar
        // artwork is deliberately not the settings artwork: this label renders
        // as a template, so the glyph's knockouts have to be transparent.
        providerAssetName = showsProviderMarker ? provider.menuBarAssetName : nil

        switch style {
        // The graphical bar modes render via `MenuBarQuotaBars`/`MenuBarBarsView`
        // rather than this text presentation; they fall back to a single value
        // text if ever constructed as a label.
        case .stackedBars, .combinedBars:
            let value = Self.combinedValue(
                fiveHour: fiveHourValue,
                weekly: weeklyValue,
                mode: valueMode
            )
            text = value.map { "\(provider.tabTitle) \($0)%" } ?? "\(provider.tabTitle) —"
            accessibilityLabel = value.map {
                "\(provider.tabTitle) quota, \($0) percent \(valueMode.accessibilityName), \(freshness)"
            } ?? "\(provider.tabTitle) quota unavailable, \(freshness)"

        case .fiveHourAndWeekly:
            text = "5H: \(Self.visibleValue(fiveHourValue)) | Week: \(Self.visibleValue(weeklyValue))"
            accessibilityLabel = [
                "\(provider.tabTitle) quota",
                Self.accessibleValue(name: "5-hour limit", value: fiveHourValue, mode: valueMode),
                Self.accessibleValue(name: "weekly limit", value: weeklyValue, mode: valueMode),
                freshness,
            ].joined(separator: "; ")
        }
    }

    private static func reading(
        for provider: AgentProvider,
        codexDisplayState: QuotaDisplayState,
        claudeState: ClaudeUsageState,
        now: Date
    ) -> Reading {
        switch provider {
        case .codex, .githubCopilot:
            let quota = codexDisplayState.displayedRecord?.presentation
            let hasValue = quota?.fiveHour != nil || quota?.weekly != nil
            return Reading(
                fiveHourUsed: quota?.fiveHour?.usedPercent,
                weeklyUsed: quota?.weekly?.usedPercent,
                freshness: hasValue
                    ? (codexDisplayState.mode == .confirmedCompleted ? .confirmed : .cached)
                    : nil
            )
        case .claudeCode:
            guard let presentation = claudeState.presentation else {
                return Reading(fiveHourUsed: nil, weeklyUsed: nil, freshness: nil)
            }
            let model = ClaudeUsageDisplayModel(presentation: presentation, now: now)
            return Reading(
                fiveHourUsed: eligibleUsed(model.fiveHour),
                weeklyUsed: eligibleUsed(model.sevenDay),
                freshness: MenuProviderSummary.freshness(for: presentation.delivery)
            )
        }
    }

    /// A reset Claude window carries no meaningful utilization yet, so it is
    /// treated as unavailable rather than 0% — mirroring `MenuProviderSummary`.
    private static func eligibleUsed(_ window: ClaudeUsageDisplayModel.Window?) -> Int? {
        guard let window, !window.hasReset else { return nil }
        return window.usedPercent
    }

    private static func combinedValue(
        fiveHour: Int?,
        weekly: Int?,
        mode: QuotaValueMode
    ) -> Int? {
        let values = [fiveHour, weekly].compactMap { $0 }
        return switch mode {
        case .remaining: values.min()
        case .used: values.max()
        }
    }

    private static func visibleValue(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }

    private static func accessibleValue(
        name: String,
        value: Int?,
        mode: QuotaValueMode
    ) -> String {
        value.map { "\(name), \($0) percent \(mode.accessibilityName)" }
            ?? "\(name) unavailable"
    }
}
