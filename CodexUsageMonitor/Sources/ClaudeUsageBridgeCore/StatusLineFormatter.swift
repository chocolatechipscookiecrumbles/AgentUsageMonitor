import Foundation

/// The single line printed to stdout when the bridge is not run with `--quiet`.
/// Claude Code shows this in its status line. Mirrors the former Python output.
public func statusLine(for snapshot: RateLimitSnapshot?) -> String {
    guard let snapshot else { return "Claude usage: unavailable" }

    var parts: [String] = []
    if let fiveHour = snapshot.fiveHour {
        parts.append("5h \(percentText(fiveHour.usedPercentage))%")
    }
    if let sevenDay = snapshot.sevenDay {
        parts.append("7d \(percentText(sevenDay.usedPercentage))%")
    }

    guard !parts.isEmpty else { return "Claude usage: unavailable" }
    return "Claude usage: " + parts.joined(separator: " · ")
}

/// Rounds to a whole percent, matching Python's `f"{value:.0f}"` (round-half-to-even).
private func percentText(_ value: Double) -> String {
    String(Int(value.rounded(.toNearestOrEven)))
}
