import Foundation

/// Provider-native token evidence for one reconciled local request.
///
/// The optional categories are unavailable only when that provider does not
/// report them. Construction is deliberately failable: malformed records must
/// stop at the reconciliation boundary rather than become plausible activity.
struct LocalActivityTokenBreakdown: Sendable, Equatable, Codable {
    let inputTokens: Int64
    let cacheCreationTokens: Int64?
    let cachedInputTokens: Int64?
    let outputTokens: Int64
    let reasoningOutputTokens: Int64?
    let totalTokens: Int64

    init?(
        provider: AgentProvider,
        inputTokens: Int64,
        cacheCreationTokens: Int64? = nil,
        cachedInputTokens: Int64? = nil,
        outputTokens: Int64,
        reasoningOutputTokens: Int64? = nil,
        reportedTotalTokens: Int64? = nil
    ) {
        guard inputTokens >= 0,
              outputTokens >= 0,
              cacheCreationTokens.map({ $0 >= 0 }) ?? true,
              cachedInputTokens.map({ $0 >= 0 }) ?? true,
              reasoningOutputTokens.map({ $0 >= 0 }) ?? true
        else { return nil }

        let normalizedTotal: Int64
        switch provider {
        case .codex:
            guard cacheCreationTokens == nil,
                  cachedInputTokens.map({ $0 <= inputTokens }) ?? true,
                  reasoningOutputTokens.map({ $0 <= outputTokens }) ?? true,
                  let total = Self.sum(inputTokens, outputTokens)
            else { return nil }
            normalizedTotal = total

        case .claudeCode:
            guard reasoningOutputTokens == nil,
                  let inputAndOutput = Self.sum(inputTokens, outputTokens),
                  let withCacheCreation = Self.sum(inputAndOutput, cacheCreationTokens ?? 0),
                  let total = Self.sum(withCacheCreation, cachedInputTokens ?? 0)
            else { return nil }
            normalizedTotal = total

        case .githubCopilot:
            return nil
        }

        guard reportedTotalTokens.map({ $0 == normalizedTotal }) ?? true else { return nil }

        self.inputTokens = inputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        totalTokens = normalizedTotal
    }

    static func zero(for provider: AgentProvider) -> Self? {
        switch provider {
        case .codex:
            Self(
                provider: provider,
                inputTokens: 0,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0
            )
        case .claudeCode:
            Self(
                provider: provider,
                inputTokens: 0,
                cacheCreationTokens: 0,
                cachedInputTokens: 0,
                outputTokens: 0
            )
        case .githubCopilot:
            nil
        }
    }

    fileprivate static func sum(_ lhs: Int64, _ rhs: Int64) -> Int64? {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }
}

struct LocalActivityRequest: Sendable, Equatable, Identifiable, Codable {
    let id: String
    let provider: AgentProvider
    let occurredAt: Date
    let modelID: String?
    let tokens: LocalActivityTokenBreakdown
}

/// One chart bar. It carries its own end because the bar's width is a calendar
/// step, not a constant: a 30-minute interval and a daylight-saving day are
/// both exactly one bucket.
struct LocalActivityBucket: Sendable, Equatable, Identifiable {
    let id: Date
    let startedAt: Date
    let endedAt: Date
    let totalTokens: Int64
}

struct LocalActivityModelShare: Sendable, Equatable {
    let shortName: String
    let sourceModelIDs: [String]
    let totalTokens: Int64
    let fraction: Double
}

struct ProviderLocalActivitySnapshot: Sendable, Equatable {
    let provider: AgentProvider
    let range: TokenMonitorRange
    let rangeStartedAt: Date
    let generatedAt: Date
    let rangeTokens: LocalActivityTokenBreakdown
    let requestCount: Int
    let buckets: [LocalActivityBucket]
    let modelUsage: [LocalActivityModelShare]
    let lastRequest: LocalActivityRequest?
}

enum ProviderLocalActivityUnavailability: Sendable, Equatable {
    case localRecordsMissing
    case unsafeToRead
}

enum ProviderLocalActivityState: Sendable, Equatable {
    case loading
    case available(ProviderLocalActivitySnapshot)
    case noActivity(
        range: TokenMonitorRange,
        rangeStartedAt: Date,
        lastRequest: LocalActivityRequest?
    )
    case unavailable(ProviderLocalActivityUnavailability)
}

/// The sole pure boundary that converts reconciled requests into presentation
/// data. Sources must already have removed replayed or duplicate cumulative,
/// streaming, and copied-sidechain representations while preserving every
/// unique reconciled main-agent, subagent, and sidechain request.
enum LocalActivityAggregation {
    static func state(
        provider: AgentProvider,
        requests: [LocalActivityRequest],
        range: TokenMonitorRange = .day,
        generatedAt: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ProviderLocalActivityState? {
        guard let snapshot = snapshot(
            provider: provider,
            requests: requests,
            range: range,
            generatedAt: generatedAt,
            calendar: calendar
        ) else { return nil }

        if snapshot.rangeTokens.totalTokens == 0 {
            return .noActivity(
                range: range,
                rangeStartedAt: snapshot.rangeStartedAt,
                lastRequest: snapshot.lastRequest
            )
        }
        return .available(snapshot)
    }

    static func snapshot(
        provider: AgentProvider,
        requests: [LocalActivityRequest],
        range: TokenMonitorRange = .day,
        generatedAt: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ProviderLocalActivitySnapshot? {
        guard requests.allSatisfy({ $0.provider == provider }),
              Set(requests.map(\.id)).count == requests.count,
              let interval = calendar.dateInterval(of: range.intervalComponent, for: generatedAt)
        else { return nil }

        let inRange = requestsInRange(requests, interval: interval, generatedAt: generatedAt)

        guard let rangeTokens = aggregateTokens(provider: provider, requests: inRange),
              let buckets = buckets(
                requests: inRange,
                rangeStartedAt: interval.start,
                range: range,
                generatedAt: generatedAt,
                calendar: calendar
              ),
              let bucketTotal = sum(buckets.map(\.totalTokens)),
              bucketTotal == rangeTokens.totalTokens
        else { return nil }

        return ProviderLocalActivitySnapshot(
            provider: provider,
            range: range,
            rangeStartedAt: interval.start,
            generatedAt: generatedAt,
            rangeTokens: rangeTokens,
            requestCount: inRange.count,
            buckets: buckets,
            modelUsage: modelUsage(for: inRange, rangeTotal: rangeTokens.totalTokens),
            lastRequest: lastRequest(in: requests)
        )
    }

    /// Last Request is deliberately drawn from *every* observed request rather
    /// than from this set, so a quiet day or week still names the most recent
    /// activity instead of reading as if none was ever seen.
    private static func requestsInRange(
        _ requests: [LocalActivityRequest],
        interval: DateInterval,
        generatedAt: Date
    ) -> [LocalActivityRequest] {
        requests.filter {
            $0.occurredAt >= interval.start && $0.occurredAt < interval.end && $0.occurredAt <= generatedAt
        }
    }

    private static func aggregateTokens(
        provider: AgentProvider,
        requests: [LocalActivityRequest]
    ) -> LocalActivityTokenBreakdown? {
        let inputTokens = sum(requests.map { $0.tokens.inputTokens })
        let outputTokens = sum(requests.map { $0.tokens.outputTokens })
        guard let inputTokens, let outputTokens else { return nil }

        switch provider {
        case .codex:
            guard let cachedInputTokens = sum(requests.map { $0.tokens.cachedInputTokens ?? 0 }),
                  let reasoningOutputTokens = sum(requests.map { $0.tokens.reasoningOutputTokens ?? 0 })
            else { return nil }
            return LocalActivityTokenBreakdown(
                provider: provider,
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens,
                reasoningOutputTokens: reasoningOutputTokens
            )

        case .claudeCode:
            guard let cacheCreationTokens = sum(requests.map { $0.tokens.cacheCreationTokens ?? 0 }),
                  let cachedInputTokens = sum(requests.map { $0.tokens.cachedInputTokens ?? 0 })
            else { return nil }
            return LocalActivityTokenBreakdown(
                provider: provider,
                inputTokens: inputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens
            )

        case .githubCopilot:
            return nil
        }
    }

    private static func buckets(
        requests: [LocalActivityRequest],
        rangeStartedAt: Date,
        range: TokenMonitorRange,
        generatedAt: Date,
        calendar: Calendar
    ) -> [LocalActivityBucket]? {
        var starts: [Date] = []
        var endsByStart: [Date: Date] = [:]
        var nextStart = rangeStartedAt

        while nextStart <= generatedAt {
            guard let end = range.bucketEnd(after: nextStart, calendar: calendar) else { return nil }
            starts.append(nextStart)
            endsByStart[nextStart] = end
            nextStart = end
        }

        var totalsByStart = Dictionary(uniqueKeysWithValues: starts.map { ($0, Int64.zero) })
        for request in requests {
            guard let intervalStart = starts.last(where: { $0 <= request.occurredAt }),
                  let total = LocalActivityTokenBreakdown.sum(
                    totalsByStart[intervalStart] ?? 0,
                    request.tokens.totalTokens
                  )
            else { return nil }
            totalsByStart[intervalStart] = total
        }

        return starts.compactMap { start in
            guard let total = totalsByStart[start], let end = endsByStart[start] else { return nil }
            return LocalActivityBucket(
                id: start,
                startedAt: start,
                endedAt: end,
                totalTokens: total
            )
        }
    }

    private static func modelUsage(
        for requests: [LocalActivityRequest],
        rangeTotal: Int64
    ) -> [LocalActivityModelShare] {
        guard rangeTotal > 0 else { return [] }

        struct Group {
            var sourceModelIDs: Set<String> = []
            var totalTokens: Int64 = 0
        }

        var groups: [String: Group] = [:]
        for request in requests {
            let shortName = LocalActivityModelName.shortName(for: request.modelID)
            var group = groups[shortName] ?? Group()
            guard let total = LocalActivityTokenBreakdown.sum(group.totalTokens, request.tokens.totalTokens) else {
                return []
            }
            group.totalTokens = total
            if let modelID = request.modelID, !modelID.isEmpty {
                group.sourceModelIDs.insert(modelID)
            }
            groups[shortName] = group
        }

        let entries: [(shortName: String, group: Group)] = groups.map {
            (shortName: $0.key, group: $0.value)
        }
        let ranked = entries.sorted { lhs, rhs in
            if lhs.group.totalTokens == rhs.group.totalTokens {
                return lhs.shortName < rhs.shortName
            }
            return lhs.group.totalTokens > rhs.group.totalTokens
        }

        var shares = ranked.prefix(3).map {
            LocalActivityModelShare(
                shortName: $0.shortName,
                sourceModelIDs: $0.group.sourceModelIDs.sorted(),
                totalTokens: $0.group.totalTokens,
                fraction: Double($0.group.totalTokens) / Double(rangeTotal)
            )
        }
        let remainder = ranked.dropFirst(3)
        if !remainder.isEmpty,
           let totalTokens = sum(remainder.map { $0.group.totalTokens }) {
            shares.append(
                LocalActivityModelShare(
                    shortName: "Other · \(remainder.count) models",
                    sourceModelIDs: remainder.flatMap { $0.group.sourceModelIDs }.sorted(),
                    totalTokens: totalTokens,
                    fraction: Double(totalTokens) / Double(rangeTotal)
                )
            )
        }
        return shares
    }

    private static func lastRequest(in requests: [LocalActivityRequest]) -> LocalActivityRequest? {
        requests.sorted {
            $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt > $1.occurredAt
        }.first
    }

    private static func sum(_ values: [Int64]) -> Int64? {
        values.reduce(Int64.zero) { partial, value in
            guard let partial else { return nil }
            return LocalActivityTokenBreakdown.sum(partial, value)
        }
    }
}

enum LocalActivityModelName {
    static let unknown = "Unknown model"

    static func shortName(for rawModelID: String?) -> String {
        guard let rawModelID else { return unknown }
        let normalized = rawModelID.lowercased()
        guard !normalized.isEmpty else { return unknown }

        if let version = version(in: normalized, family: "gpt") {
            return "GPT-\(version)"
        }
        for family in ["sonnet", "opus", "haiku"] {
            if let version = version(in: normalized, family: family) {
                return "\(family.capitalized) \(version)"
            }
        }
        return unknown
    }

    /// One or two digits not followed by another digit. Bounding the run is what
    /// keeps a dated build suffix such as `-20251001` from being read as a
    /// version component, while still allowing a minor of `10` or above.
    private static let versionComponent = "(\\d{1,2})(?![0-9])"

    private static func version(in value: String, family: String) -> String? {
        // Current identifiers put the version after the family, and the minor
        // component is genuinely optional: `sonnet-4-5`, `gpt-5.6`, `opus-5`.
        if let version = firstVersion(
            in: value,
            pattern: "\(family)[-_ ]?\(versionComponent)(?:[-_ .]\(versionComponent))?"
        ) {
            return version
        }
        // Earlier identifiers put it before the family: `claude-3-5-sonnet`.
        return firstVersion(
            in: value,
            pattern: "\(versionComponent)(?:[-_ .]\(versionComponent))?[-_ ]?\(family)"
        )
    }

    private static func firstVersion(in value: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let majorRange = Range(match.range(at: 1), in: value)
        else { return nil }
        guard let minorRange = Range(match.range(at: 2), in: value) else {
            return String(value[majorRange])
        }
        return "\(value[majorRange]).\(value[minorRange])"
    }
}
