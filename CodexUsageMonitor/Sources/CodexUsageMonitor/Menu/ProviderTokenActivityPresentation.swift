import Foundation

/// Everything the Token activity card renders, derived once from one published
/// activity state.
///
/// Formatting and copy live here rather than in the view so the number rules
/// and the sanitized state wording are readable in one place, and so hovering a
/// bar can never change anything except the chart's own detail line.
struct ProviderTokenActivityPresentation: Equatable {
    static let title = "Token activity"
    static let scope = "This Mac · observed"
    static let hoverResting = "Hover over a bar for details"
    static let emptyDay = "No activity observed today"

    let provider: AgentProvider
    let content: Content

    enum Content: Equatable {
        /// Loading and unavailable states stay compact: no chart, no rows.
        case compact(message: String, detail: String?)
        case expanded(Expanded)
    }

    struct Expanded: Equatable {
        let todayTokens: String
        let todayExactTokens: String
        let dayStartedAt: Date
        let domainEndsAt: Date
        let buckets: [LocalActivityBucket]
        let hasObservedActivity: Bool
        let categories: [Row]
        let requests: Row
        /// The request count reads as a caption under the day's total rather
        /// than as a fifth metric cell, which keeps the categories a clean
        /// two-by-two grid.
        let requestsSummary: String
        let modelUsage: [ModelRow]
        let lastRequest: LastRequest?
        let chartAccessibilityValue: String
    }

    struct Row: Equatable, Identifiable {
        let id: String
        let label: String
        let value: String
        /// Exact counts stay reachable even though the visible value is compact.
        let accessibilityValue: String
    }

    struct ModelRow: Equatable, Identifiable {
        var id: String { shortName }
        let shortName: String
        let value: String
        let sharePercent: Int
        let accessibilityValue: String
    }

    struct LastRequest: Equatable {
        let totalAndTime: String
        let shortModelName: String
        let accessibilityValue: String
    }

    init(provider: AgentProvider, state: ProviderLocalActivityState, now: Date = .now) {
        self.provider = provider

        switch state {
        case .loading:
            content = .compact(message: "Reading activity…", detail: nil)

        case .unavailable(.localRecordsMissing):
            content = .compact(
                message: "No local records found",
                detail: "Use \(provider.tabTitle) on this Mac to see activity here."
            )

        case .unavailable(.unsafeToRead):
            content = .compact(
                message: "Activity unavailable",
                detail: "Local records couldn't be read safely."
            )

        case .available(let snapshot):
            content = .expanded(
                Self.expanded(
                    provider: provider,
                    tokens: snapshot.todayTokens,
                    dayStartedAt: snapshot.dayStartedAt,
                    buckets: snapshot.buckets,
                    requestCount: snapshot.requestCount,
                    modelUsage: snapshot.modelUsage,
                    lastRequest: snapshot.lastRequest,
                    now: snapshot.generatedAt
                )
            )

        case .noActivity(let dayStartedAt, let lastRequest):
            // The source is readable and the day is genuinely empty, so zeros
            // are observed values rather than missing evidence. No bar is
            // synthesized; the plot keeps its frame and reads as empty.
            content = .expanded(
                Self.expanded(
                    provider: provider,
                    tokens: LocalActivityTokenBreakdown.zero(for: provider),
                    dayStartedAt: dayStartedAt,
                    buckets: [],
                    requestCount: 0,
                    modelUsage: [],
                    lastRequest: lastRequest,
                    now: now
                )
            )
        }
    }

    private static func expanded(
        provider: AgentProvider,
        tokens: LocalActivityTokenBreakdown?,
        dayStartedAt: Date,
        buckets: [LocalActivityBucket],
        requestCount: Int,
        modelUsage: [LocalActivityModelShare],
        lastRequest: LocalActivityRequest?,
        now: Date
    ) -> Expanded {
        let total = tokens?.totalTokens ?? 0
        // The domain always ends at the close of the interval in progress, so
        // the plot spans the elapsed day rather than only the observed part.
        let domainEndsAt = buckets.last.map { $0.startedAt.addingTimeInterval(1800) }
            ?? max(dayStartedAt.addingTimeInterval(1800), currentIntervalEnd(dayStartedAt: dayStartedAt, now: now))

        return Expanded(
            todayTokens: compactTokens(total),
            todayExactTokens: exactTokens(total),
            dayStartedAt: dayStartedAt,
            domainEndsAt: domainEndsAt,
            buckets: buckets,
            hasObservedActivity: total > 0,
            categories: categories(provider: provider, tokens: tokens),
            requests: Row(
                id: "requests",
                label: "Requests",
                value: requestCount.formatted(.number),
                accessibilityValue: requestCount.formatted(.number)
            ),
            requestsSummary: requestCount == 1
                ? "1 request"
                : "\(requestCount.formatted(.number)) requests",
            modelUsage: modelUsage.map { share in
                let percent = Int((share.fraction * 100).rounded())
                return ModelRow(
                    shortName: share.shortName,
                    value: compactTokens(share.totalTokens),
                    sharePercent: percent,
                    accessibilityValue: [
                        "\(exactTokens(share.totalTokens)) tokens",
                        "\(percent) percent",
                        share.sourceModelIDs.isEmpty ? nil : share.sourceModelIDs.joined(separator: ", "),
                    ]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                )
            },
            lastRequest: lastRequest.map { lastRequestRow(from: $0, now: now) },
            chartAccessibilityValue: chartAccessibilityValue(
                buckets: buckets,
                total: total
            )
        )
    }

    private static func currentIntervalEnd(dayStartedAt: Date, now: Date) -> Date {
        let elapsed = max(0, now.timeIntervalSince(dayStartedAt))
        let completedIntervals = (elapsed / 1800).rounded(.down)
        return dayStartedAt.addingTimeInterval((completedIntervals + 1) * 1800)
    }

    private static func categories(
        provider: AgentProvider,
        tokens: LocalActivityTokenBreakdown?
    ) -> [Row] {
        // The four rows are structurally stable in every expanded state, so a
        // category a provider does not report reads Unavailable rather than 0.
        let definitions: [(id: String, label: String, value: Int64?)]
        switch provider {
        case .codex:
            definitions = [
                ("input", "Input", tokens?.inputTokens),
                ("cached-input", "Cached input", tokens?.cachedInputTokens),
                ("output", "Output", tokens?.outputTokens),
                ("reasoning", "Reasoning", tokens?.reasoningOutputTokens),
            ]
        case .claudeCode:
            definitions = [
                ("input", "Input", tokens?.inputTokens),
                ("cache-creation", "Cache creation", tokens?.cacheCreationTokens),
                ("cache-read", "Cache read", tokens?.cachedInputTokens),
                ("output", "Output", tokens?.outputTokens),
            ]
        case .githubCopilot:
            definitions = []
        }

        return definitions.map {
            Row(
                id: $0.id,
                label: $0.label,
                value: $0.value.map(compactTokens) ?? "Unavailable",
                accessibilityValue: $0.value.map(exactTokens) ?? "Unavailable"
            )
        }
    }

    private static func lastRequestRow(from request: LocalActivityRequest, now: Date) -> LastRequest {
        let time = request.occurredAt.formatted(date: .omitted, time: .shortened)
        let isToday = Calendar.autoupdatingCurrent.isDate(request.occurredAt, inSameDayAs: now)
        let when = isToday
            ? time
            : "\(request.occurredAt.formatted(date: .abbreviated, time: .omitted)) \(time)"
        let shortName = LocalActivityModelName.shortName(for: request.modelID)

        return LastRequest(
            totalAndTime: "\(compactTokens(request.tokens.totalTokens)) · \(when)",
            shortModelName: shortName,
            // Accessibility keeps the provider-native breakdown and the raw
            // identifier that the compact row deliberately omits.
            accessibilityValue: [
                "\(exactTokens(request.tokens.totalTokens)) tokens",
                "input \(exactTokens(request.tokens.inputTokens))",
                request.tokens.cacheCreationTokens.map { "cache creation \(exactTokens($0))" },
                request.tokens.cachedInputTokens.map { "cached input \(exactTokens($0))" },
                "output \(exactTokens(request.tokens.outputTokens))",
                request.tokens.reasoningOutputTokens.map { "reasoning \(exactTokens($0))" },
                when,
                request.modelID.map { "model \($0)" } ?? shortName,
            ]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }

    private static func chartAccessibilityValue(
        buckets: [LocalActivityBucket],
        total: Int64
    ) -> String {
        guard !buckets.isEmpty else {
            return "\(emptyDay). \(exactTokens(total)) tokens today."
        }
        let intervals = buckets.map {
            let end = $0.startedAt.addingTimeInterval(1800)
            return "\(intervalRange(start: $0.startedAt, end: end)), \(exactTokens($0.totalTokens)) tokens"
        }
        return "\(exactTokens(total)) tokens today. " + intervals.joined(separator: ". ") + "."
    }

    static func intervalRange(start: Date, end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    static func hoverDetail(for bucket: LocalActivityBucket) -> String {
        let end = bucket.startedAt.addingTimeInterval(1800)
        return "\(intervalRange(start: bucket.startedAt, end: end)) · \(compactTokens(bucket.totalTokens)) tokens"
    }

    /// Compact notation that keeps one decimal, because a menu-bar card that
    /// rounds 141,600 to "142K" hides the difference between similar days. A
    /// positive count never renders as `0`; it falls back to its exact value.
    static func compactTokens(_ value: Int64) -> String {
        guard value != 0 else { return "0" }
        let compact = value.formatted(
            .number.notation(.compactName).precision(.fractionLength(0...1))
        )
        guard compact != "0" else { return exactTokens(value) }
        return compact
    }

    static func exactTokens(_ value: Int64) -> String {
        value.formatted(.number)
    }
}
