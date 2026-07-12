import Foundation

actor QuotaRepository {
    private let collector: CodexQuotaCollector
    private let historyStore: QuotaHistoryStore

    init(
        collector: CodexQuotaCollector = CodexQuotaCollector(),
        historyStore: QuotaHistoryStore = QuotaHistoryStore()
    ) {
        self.collector = collector
        self.historyStore = historyStore
    }

    func refresh() async -> QuotaRecord {
        let presentation = await collector.refresh()
        guard let entry = QuotaHistoryEntry(presentation: presentation) else {
            return .withoutForecasts(presentation)
        }
        historyStore.append(entry)
        let entries = historyStore.entries(matching: presentation)
        return QuotaRecord(
            presentation: presentation,
            fiveHourForecast: QuotaForecast.calculate(for: .fiveHour, current: entry, entries: entries),
            weeklyForecast: QuotaForecast.calculate(for: .weekly, current: entry, entries: entries)
        )
    }
}
