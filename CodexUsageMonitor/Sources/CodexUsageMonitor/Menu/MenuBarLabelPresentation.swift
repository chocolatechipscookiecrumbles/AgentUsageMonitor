import Foundation

struct MenuBarLabelPresentation: Equatable, Sendable {
    let text: String
    let showsGauge: Bool
    let showsPauseMarker: Bool
    let providerAssetName: String?
    let accessibilityLabel: String

    init(
        displayState: QuotaDisplayState,
        style: MenuBarDisplayStyle,
        valueMode: QuotaValueMode
    ) {
        let quota = displayState.displayedRecord?.presentation
        let fiveHourValue = quota?.fiveHour.map(valueMode.value(for:))
        let weeklyValue = quota?.weekly.map(valueMode.value(for:))
        let freshness = displayState.mode == .confirmedCompleted ? "confirmed" : "cached"

        showsGauge = style == .gaugeAndLowest
        showsPauseMarker = displayState.mode == .cachedPaused
        providerAssetName = nil

        switch style {
        // The graphical bar modes render via `MenuBarQuotaBars`/`MenuBarBarsView`
        // rather than this text presentation; they fall back to the gauge text
        // if ever constructed as a label.
        case .gaugeAndLowest, .stackedBars, .combinedBars:
            let value = Self.gaugeValue(
                fiveHour: fiveHourValue,
                weekly: weeklyValue,
                mode: valueMode
            )
            text = value.map { "Codex \($0)%" } ?? "Codex —"
            accessibilityLabel = value.map {
                "Codex quota, \($0) percent \(valueMode.accessibilityName), \(freshness)"
            } ?? "Codex quota unavailable, \(freshness)"

        case .fiveHourAndWeekly:
            text = "5H: \(Self.visibleValue(fiveHourValue)) | Week: \(Self.visibleValue(weeklyValue))"
            accessibilityLabel = [
                Self.accessibleValue(name: "5-hour limit", value: fiveHourValue, mode: valueMode),
                Self.accessibleValue(name: "weekly limit", value: weeklyValue, mode: valueMode),
                freshness,
            ].joined(separator: "; ")
        }
    }

    init(
        displayState: QuotaDisplayState,
        providerSummaries: [MenuProviderSummary],
        style: MenuBarDisplayStyle,
        valueMode: QuotaValueMode
    ) {
        let availableSummaries = providerSummaries.filter { $0.usedPercent != nil }

        if availableSummaries.isEmpty
            || (availableSummaries.count == 1 && availableSummaries[0].provider == .codex) {
            self.init(displayState: displayState, style: style, valueMode: valueMode)
            return
        }

        guard let summary = MenuProviderSummary.mostAtRisk(in: availableSummaries),
              let value = summary.visiblePercent(for: valueMode),
              let freshness = summary.freshness else {
            self.init(displayState: displayState, style: style, valueMode: valueMode)
            return
        }

        self.init(
            text: "\(value)%",
            showsGauge: false,
            showsPauseMarker: !freshness.isConfirmed,
            providerAssetName: summary.provider.settingsAssetName,
            accessibilityLabel:
                "\(summary.provider.title) quota, \(value) percent \(valueMode.accessibilityName), \(freshness.accessibilityName)"
        )
    }

    private init(
        text: String,
        showsGauge: Bool,
        showsPauseMarker: Bool,
        providerAssetName: String?,
        accessibilityLabel: String
    ) {
        self.text = text
        self.showsGauge = showsGauge
        self.showsPauseMarker = showsPauseMarker
        self.providerAssetName = providerAssetName
        self.accessibilityLabel = accessibilityLabel
    }

    private static func gaugeValue(
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
