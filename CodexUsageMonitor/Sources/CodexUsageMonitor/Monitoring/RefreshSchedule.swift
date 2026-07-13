import Foundation

enum RefreshMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case oneMinute = "one-minute"
    case ninetySeconds = "ninety-seconds"
    case twoMinutes = "two-minutes"
    case fiveMinutes = "five-minutes"
    case tenMinutes = "ten-minutes"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .oneMinute: "1 minute"
        case .ninetySeconds: "1 minute 30 seconds"
        case .twoMinutes: "2 minutes"
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        }
    }

    var fixedInterval: TimeInterval? {
        switch self {
        case .automatic: nil
        case .oneMinute: 60
        case .ninetySeconds: 90
        case .twoMinutes: 120
        case .fiveMinutes: 300
        case .tenMinutes: 600
        }
    }
}

enum RefreshScheduleReason: Equatable, Sendable {
    case fixed(RefreshMode)
    case automaticNormal
    case fastConsumption
    case lowRemaining
    case imminentThreshold
    case qualifiedExhaustion
    case resetVerification
    case failureBackoff

    var displayName: String {
        switch self {
        case .fixed(let mode): "Fixed at \(mode.displayName)"
        case .automaticNormal: "Automatic: steady usage"
        case .fastConsumption: "Automatic: faster consumption"
        case .lowRemaining: "Automatic: low remaining quota"
        case .imminentThreshold: "Automatic burst: warning threshold approaching"
        case .qualifiedExhaustion: "Automatic: qualified exhaustion approaching"
        case .resetVerification: "Automatic: quota reset approaching"
        case .failureBackoff: "Automatic: backed off to five minutes after refresh failures"
        }
    }
}

struct RefreshScheduleDecision: Equatable, Sendable {
    let interval: TimeInterval
    let reason: RefreshScheduleReason
    let isAutomaticBurst: Bool
    let isBurstConditionActive: Bool
}

enum AdaptiveRefreshPolicy {
    private static let burstInterval: TimeInterval = 30
    private static let maximumBurstDuration: TimeInterval = 10 * 60
    private static let warningThresholds = [50, 25, 10, 5]

    static func decision(
        mode: RefreshMode,
        record: QuotaRecord?,
        consecutiveFailures: Int,
        burstStartedAt: Date?,
        now: Date = .now
    ) -> RefreshScheduleDecision {
        if let interval = mode.fixedInterval {
            return RefreshScheduleDecision(interval: interval, reason: .fixed(mode), isAutomaticBurst: false, isBurstConditionActive: false)
        }

        let trigger = burstTrigger(for: record, now: now)
        if consecutiveFailures >= 2 {
            return RefreshScheduleDecision(interval: 300, reason: .failureBackoff, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }

        if let trigger,
           burstStartedAt.map({ now.timeIntervalSince($0) < maximumBurstDuration }) ?? true {
            return RefreshScheduleDecision(interval: burstInterval, reason: trigger, isAutomaticBurst: true, isBurstConditionActive: true)
        }

        if consecutiveFailures == 1 {
            return RefreshScheduleDecision(interval: 300, reason: .failureBackoff, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }

        guard let record else {
            return RefreshScheduleDecision(interval: 300, reason: .automaticNormal, isAutomaticBurst: false, isBurstConditionActive: false)
        }

        let remaining = minimumRemaining(in: record)
        let rate = maximumRate(in: record)
        if remaining <= 10 {
            return RefreshScheduleDecision(interval: 60, reason: .lowRemaining, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }
        if hasQualifiedExhaustion(record, within: nil, now: now) {
            return RefreshScheduleDecision(interval: 60, reason: .qualifiedExhaustion, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }
        if hasReset(record, within: 30 * 60, now: now) {
            return RefreshScheduleDecision(interval: 60, reason: .resetVerification, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }
        if remaining <= 25 || rate >= 5 {
            return RefreshScheduleDecision(interval: 90, reason: .fastConsumption, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }
        if remaining <= 50 || rate >= 1 {
            return RefreshScheduleDecision(interval: 120, reason: .fastConsumption, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
        }
        return RefreshScheduleDecision(interval: 300, reason: .automaticNormal, isAutomaticBurst: false, isBurstConditionActive: trigger != nil)
    }

    private static func burstTrigger(for record: QuotaRecord?, now: Date) -> RefreshScheduleReason? {
        guard let record else { return nil }
        if thresholdCrossingIsImminent(record, now: now) { return .imminentThreshold }
        if hasQualifiedExhaustion(record, within: maximumBurstDuration, now: now) { return .qualifiedExhaustion }
        if hasReset(record, within: maximumBurstDuration, now: now, includeRecentlyOverdue: true) { return .resetVerification }
        return nil
    }

    private static func thresholdCrossingIsImminent(_ record: QuotaRecord, now: Date) -> Bool {
        let pairs = [
            (record.presentation.fiveHour, record.fiveHourForecast),
            (record.presentation.weekly, record.weeklyForecast),
        ]
        return pairs.contains { window, forecast in
            guard let window, let forecast, forecast.percentPerHour > 0,
                  let nextThreshold = warningThresholds.filter({ $0 < window.remainingPercent }).max()
            else { return false }
            let seconds = Double(window.remainingPercent - nextThreshold) / forecast.percentPerHour * 3_600
            return seconds >= 0 && seconds <= maximumBurstDuration && forecast.resetAt > now
        }
    }

    private static func hasQualifiedExhaustion(_ record: QuotaRecord, within interval: TimeInterval?, now: Date) -> Bool {
        [record.fiveHourForecast, record.weeklyForecast].compactMap { $0 }.contains { forecast in
            guard forecast.confidence == .medium || forecast.confidence == .high,
                  forecast.projectedExhaustionAt <= forecast.resetAt.addingTimeInterval(-15 * 60),
                  forecast.projectedExhaustionAt >= now
            else { return false }
            return interval.map { forecast.projectedExhaustionAt.timeIntervalSince(now) <= $0 } ?? true
        }
    }

    private static func hasReset(
        _ record: QuotaRecord,
        within interval: TimeInterval,
        now: Date,
        includeRecentlyOverdue: Bool = false
    ) -> Bool {
        [record.presentation.fiveHour?.resetAt, record.presentation.weekly?.resetAt]
            .compactMap { $0 }
            .contains { resetAt in
                let seconds = resetAt.timeIntervalSince(now)
                return seconds >= (includeRecentlyOverdue ? -interval : 0) && seconds <= interval
            }
    }

    private static func minimumRemaining(in record: QuotaRecord) -> Int {
        [record.presentation.fiveHour?.remainingPercent, record.presentation.weekly?.remainingPercent]
            .compactMap { $0 }
            .min() ?? 100
    }

    private static func maximumRate(in record: QuotaRecord) -> Double {
        [record.fiveHourForecast?.percentPerHour, record.weeklyForecast?.percentPerHour]
            .compactMap { $0 }
            .max() ?? 0
    }
}
