import Foundation

struct CodexForecastPresentation {
    let forecast: QuotaForecast

    var text: String {
        "Projected exhaustion \(forecast.projectedExhaustionAt.formatted(date: .abbreviated, time: .shortened)) · \(forecast.confidence.rawValue.capitalized) confidence"
    }
}
