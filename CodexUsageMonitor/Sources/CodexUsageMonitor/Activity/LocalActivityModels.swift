import Foundation

/// Provider-native token evidence for one reconciled local request.
///
/// The optional categories are unavailable only when that provider does not
/// report them. Construction is deliberately failable: malformed records must
/// stop at the reconciliation boundary rather than become plausible activity.
struct LocalActivityTokenBreakdown: Sendable, Equatable {
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

struct LocalActivityRequest: Sendable, Equatable, Identifiable {
    let id: String
    let provider: AgentProvider
    let occurredAt: Date
    let modelID: String?
    let tokens: LocalActivityTokenBreakdown
}

struct LocalActivityBucket: Sendable, Equatable, Identifiable {
    let id: Date
    let startedAt: Date
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
    let dayStartedAt: Date
    let generatedAt: Date
    let todayTokens: LocalActivityTokenBreakdown
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
    case noActivity(dayStartedAt: Date, lastRequest: LocalActivityRequest?)
    case unavailable(ProviderLocalActivityUnavailability)
}

/// The sole pure boundary that converts reconciled requests into presentation
/// data. Sources must already have removed replayed cumulative, streaming, and
/// sidechain records before they reach this type.
enum LocalActivityAggregation {
    static func state(
        provider: AgentProvider,
        requests: [LocalActivityRequest],
        generatedAt: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ProviderLocalActivityState? {
        guard let snapshot = snapshot(
            provider: provider,
            requests: requests,
            generatedAt: generatedAt,
            calendar: calendar
        ) else { return nil }

        if snapshot.todayTokens.totalTokens == 0 {
            return .noActivity(
                dayStartedAt: snapshot.dayStartedAt,
                lastRequest: snapshot.lastRequest
            )
        }
        return .available(snapshot)
    }

    static func snapshot(
        provider: AgentProvider,
        requests: [LocalActivityRequest],
        generatedAt: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ProviderLocalActivitySnapshot? {
        guard requests.allSatisfy({ $0.provider == provider }),
              Set(requests.map(\.id)).count == requests.count,
              let dayStartedAt = calendar.dateInterval(of: .day, for: generatedAt)?.start,
              let dayEndedAt = calendar.date(byAdding: .day, value: 1, to: dayStartedAt),
              let todayTokens = aggregateTokens(provider: provider, requests: todayRequests(
                requests,
                dayStartedAt: dayStartedAt,
                dayEndedAt: dayEndedAt,
                generatedAt: generatedAt
              )),
              let buckets = buckets(
                requests: todayRequests(
                    requests,
                    dayStartedAt: dayStartedAt,
                    dayEndedAt: dayEndedAt,
                    generatedAt: generatedAt
                ),
                dayStartedAt: dayStartedAt,
                generatedAt: generatedAt,
                calendar: calendar
              ),
              let bucketTotal = sum(buckets.map(\.totalTokens)),
              bucketTotal == todayTokens.totalTokens
        else { return nil }

        let today = todayRequests(
            requests,
            dayStartedAt: dayStartedAt,
            dayEndedAt: dayEndedAt,
            generatedAt: generatedAt
        )

        return ProviderLocalActivitySnapshot(
            provider: provider,
            dayStartedAt: dayStartedAt,
            generatedAt: generatedAt,
            todayTokens: todayTokens,
            requestCount: today.count,
            buckets: buckets,
            modelUsage: modelUsage(for: today, todayTotal: todayTokens.totalTokens),
            lastRequest: lastRequest(in: requests)
        )
    }

    private static func todayRequests(
        _ requests: [LocalActivityRequest],
        dayStartedAt: Date,
        dayEndedAt: Date,
        generatedAt: Date
    ) -> [LocalActivityRequest] {
        requests.filter {
            $0.occurredAt >= dayStartedAt && $0.occurredAt < dayEndedAt && $0.occurredAt <= generatedAt
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
        dayStartedAt: Date,
        generatedAt: Date,
        calendar: Calendar
    ) -> [LocalActivityBucket]? {
        var starts: [Date] = []
        var nextStart = dayStartedAt

        while nextStart <= generatedAt {
            starts.append(nextStart)
            guard let followingStart = calendar.date(byAdding: .minute, value: 30, to: nextStart) else {
                return nil
            }
            nextStart = followingStart
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
            totalsByStart[start].map {
                LocalActivityBucket(id: start, startedAt: start, totalTokens: $0)
            }
        }
    }

    private static func modelUsage(
        for requests: [LocalActivityRequest],
        todayTotal: Int64
    ) -> [LocalActivityModelShare] {
        guard todayTotal > 0 else { return [] }

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
                fraction: Double($0.group.totalTokens) / Double(todayTotal)
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
                    fraction: Double(totalTokens) / Double(todayTotal)
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

        if let version = version(in: normalized, pattern: "gpt[-_ ]?(\\d+)[-_ .]?(\\d+)") {
            return "GPT-\(version)"
        }
        for family in ["sonnet", "opus", "haiku"] {
            if let version = version(in: normalized, pattern: "\(family)[-_ ]?(\\d+)[-_ .]?(\\d+)") {
                return "\(family.capitalized) \(version)"
            }
        }
        return unknown
    }

    private static func version(in value: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let majorRange = Range(match.range(at: 1), in: value),
              let minorRange = Range(match.range(at: 2), in: value)
        else { return nil }
        return "\(value[majorRange]).\(value[minorRange])"
    }
}
