import SwiftUI

struct QuotaWindowRow: View {
    let title: String
    let window: QuotaWindow?
    let unavailableText: String
    let forecast: QuotaForecast?

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title): \(window.usedPercent)% used · \(window.remainingPercent)% remaining")
                if let resetAt = window.resetAt {
                    Text("Resets: \(resetAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                }
                if let forecast {
                    Text("Projected exhaustion: \(forecast.projectedExhaustionAt.formatted(date: .abbreviated, time: .shortened)) · \(forecast.confidence.rawValue) confidence")
                        .font(.caption)
                }
            }
        } else {
            Text("\(title): \(unavailableText)")
        }
    }
}
