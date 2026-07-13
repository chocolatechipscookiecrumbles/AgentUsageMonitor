import Foundation

enum QuotaValidator {
    static func isTransientEmpty(_ sample: CodexQuotaSample) -> Bool {
        guard let fiveHour = sample.fiveHour,
              fiveHour.usedPercent <= 5,
              sample.weekly.usedPercent <= 5,
              let resetAt = fiveHour.resetAt,
              let duration = fiveHour.durationMinutes
        else { return false }
        let expectedReset = sample.collectedAt.addingTimeInterval(TimeInterval(duration * 60))
        return abs(resetAt.timeIntervalSince(expectedReset)) <= 90
    }

    static func allMatch(_ samples: [CodexQuotaSample]) -> Bool {
        guard let first = samples.first, first.limitID == "codex" else { return false }
        return samples.dropFirst().allSatisfy { sample in
            sample.accountFingerprint == first.accountFingerprint &&
                sample.limitID == first.limitID &&
                windowsMatch(first.fiveHour, sample.fiveHour) &&
                windowsMatch(first.weekly, sample.weekly)
        }
    }

    static func matchesCache(_ presentation: QuotaPresentation, sample: CodexQuotaSample) -> Bool {
        presentation.accountFingerprint == sample.accountFingerprint &&
            presentation.limitID == "codex" && sample.limitID == "codex"
    }

    private static func windowsMatch(_ first: QuotaWindow?, _ second: QuotaWindow?) -> Bool {
        guard let first, let second else { return first == nil && second == nil }
        guard abs(first.usedPercent - second.usedPercent) <= 5 else { return false }
        switch (first.resetAt, second.resetAt) {
        case let (.some(left), .some(right)):
            return abs(left.timeIntervalSince(right)) <= 120
        case (.none, .none):
            return true
        default:
            return false
        }
    }
}
