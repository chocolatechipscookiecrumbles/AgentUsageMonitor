import Foundation

struct MenuBarLabelPresentation: Equatable, Sendable {
    let text: String
    let showsGauge: Bool
    let showsPauseMarker: Bool
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

        switch style {
        case .gaugeAndLowest:
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
