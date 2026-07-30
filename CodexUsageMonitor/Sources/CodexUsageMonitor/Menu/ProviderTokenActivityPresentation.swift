import Foundation

/// Everything the Token Monitor card renders, derived once from one published
/// activity state.
///
/// Formatting and copy live here rather than in the view so the number rules
/// and the sanitized state wording are readable in one place, and so hovering a
/// bar can never change anything except the chart's own detail line.
///
/// The name shown to the user is **Token Monitor**. The surrounding type names
/// still say `TokenActivity` and are deliberately left alone: they are internal
/// identifiers, and renaming them would add churn and review surface to a
/// change whose value is entirely in the copy.
struct ProviderTokenActivityPresentation: Equatable {
    static let title = "Token Monitor"
    static let hoverResting = "Hover over a bar for details"

    let provider: AgentProvider
    /// The window the card reports. Every piece of range-dependent copy and
    /// formatting below reads it, so the header line, the chart labels, the
    /// empty state, and the spoken values can never describe different windows.
    let range: TokenMonitorRange
    let content: Content

    /// The line under the title. It names the window rather than the source,
    /// so the card has to keep saying "observed on this Mac" elsewhere — the
    /// totals are local records, never account or quota usage.
    var scope: String { range.scope }

    enum Content: Equatable {
        /// Loading and unavailable states stay compact: no chart, no rows.
        case compact(message: String, detail: String?)
        case expanded(Expanded)
    }

    struct Expanded: Equatable {
        let rangeTokens: String
        let rangeExactTokens: String
        let rangeStartedAt: Date
        let domainEndsAt: Date
        let buckets: [LocalActivityBucket]
        /// The dates the chart labels, chosen here because which labels fit is
        /// a property of the range rather than of the view drawing them.
        let axisDates: [Date]
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

    init(
        provider: AgentProvider,
        state: ProviderLocalActivityState,
        range: TokenMonitorRange = .day,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.provider = provider
        // The state carries the range it was aggregated with. Trusting that
        // over the caller's preference is what keeps the header, the chart, and
        // the totals describing one window while a range change is in flight.
        switch state {
        case .available(let snapshot):
            self.range = snapshot.range
        case .noActivity(let stateRange, _, _):
            self.range = stateRange
        case .loading, .unavailable:
            self.range = range
        }

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
                    range: snapshot.range,
                    tokens: snapshot.rangeTokens,
                    rangeStartedAt: snapshot.rangeStartedAt,
                    buckets: snapshot.buckets,
                    requestCount: snapshot.requestCount,
                    modelUsage: snapshot.modelUsage,
                    lastRequest: snapshot.lastRequest,
                    now: snapshot.generatedAt,
                    calendar: calendar
                )
            )

        case .noActivity(let stateRange, let rangeStartedAt, let lastRequest):
            // The source is readable and the window is genuinely empty, so
            // zeros are observed values rather than missing evidence. No bar is
            // synthesized; the plot keeps its frame and reads as empty.
            content = .expanded(
                Self.expanded(
                    provider: provider,
                    range: stateRange,
                    tokens: LocalActivityTokenBreakdown.zero(for: provider),
                    rangeStartedAt: rangeStartedAt,
                    buckets: [],
                    requestCount: 0,
                    modelUsage: [],
                    lastRequest: lastRequest,
                    now: now,
                    calendar: calendar
                )
            )
        }
    }

    private static func expanded(
        provider: AgentProvider,
        range: TokenMonitorRange,
        tokens: LocalActivityTokenBreakdown?,
        rangeStartedAt: Date,
        buckets: [LocalActivityBucket],
        requestCount: Int,
        modelUsage: [LocalActivityModelShare],
        lastRequest: LocalActivityRequest?,
        now: Date,
        calendar: Calendar
    ) -> Expanded {
        let total = tokens?.totalTokens ?? 0
        // The domain always ends at the close of the bucket in progress, so the
        // plot spans the elapsed window rather than only the observed part.
        let domainEndsAt = buckets.last?.endedAt
            ?? currentBucketEnd(range: range, rangeStartedAt: rangeStartedAt, now: now, calendar: calendar)

        return Expanded(
            rangeTokens: compactTokens(total),
            rangeExactTokens: exactTokens(total),
            rangeStartedAt: rangeStartedAt,
            domainEndsAt: domainEndsAt,
            buckets: buckets,
            axisDates: axisDates(
                range: range,
                rangeStartedAt: rangeStartedAt,
                domainEndsAt: domainEndsAt,
                buckets: buckets
            ),
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
                range: range,
                buckets: buckets,
                total: total
            )
        )
    }

    /// Walks the range's own bucket rule forward to the bar in progress, so an
    /// empty window's plot spans exactly the same domain a populated one would.
    /// A calendar that refuses to advance falls back to one bucket wide rather
    /// than to a zero-width domain the chart cannot scale.
    private static func currentBucketEnd(
        range: TokenMonitorRange,
        rangeStartedAt: Date,
        now: Date,
        calendar: Calendar
    ) -> Date {
        var end = range.bucketEnd(after: rangeStartedAt, calendar: calendar)
            ?? rangeStartedAt.addingTimeInterval(1800)
        while end <= now, let next = range.bucketEnd(after: end, calendar: calendar) {
            end = next
        }
        return end
    }

    /// The day view labels the start, the midpoint, and the end of the elapsed
    /// span: more than three times cannot be read at 340 points. The week view
    /// labels each day, because seven weekday initials fit where seven
    /// timestamps would not.
    private static func axisDates(
        range: TokenMonitorRange,
        rangeStartedAt: Date,
        domainEndsAt: Date,
        buckets: [LocalActivityBucket]
    ) -> [Date] {
        switch range {
        case .day:
            let midpoint = rangeStartedAt.addingTimeInterval(
                domainEndsAt.timeIntervalSince(rangeStartedAt) / 2
            )
            return [rangeStartedAt, midpoint, domainEndsAt]
        case .week:
            return buckets.isEmpty ? [rangeStartedAt] : buckets.map(\.startedAt)
        }
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
        range: TokenMonitorRange,
        buckets: [LocalActivityBucket],
        total: Int64
    ) -> String {
        let window = range.scope.lowercased()
        guard !buckets.isEmpty else {
            return "\(range.emptyMessage). \(exactTokens(total)) tokens \(window)."
        }
        let intervals = buckets.map {
            "\(bucketLabel(for: $0, range: range)), \(exactTokens($0.totalTokens)) tokens"
        }
        return "\(exactTokens(total)) tokens \(window). " + intervals.joined(separator: ". ") + "."
    }

    /// What one bar covers, in the terms its range measures: a clock interval
    /// for the day view, a calendar date for the week view.
    static func bucketLabel(for bucket: LocalActivityBucket, range: TokenMonitorRange) -> String {
        switch range {
        case .day:
            return intervalRange(start: bucket.startedAt, end: bucket.endedAt)
        case .week:
            return bucket.startedAt.formatted(
                .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            )
        }
    }

    static func intervalRange(start: Date, end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    /// The label under a chart tick. Seven full timestamps do not fit at 340
    /// points, so the week view narrows each day to its weekday initial.
    func axisLabel(for date: Date) -> String {
        switch range {
        case .day:
            return date.formatted(date: .omitted, time: .shortened)
        case .week:
            return date.formatted(.dateTime.weekday(.narrow))
        }
    }

    func hoverDetail(for bucket: LocalActivityBucket) -> String {
        "\(Self.bucketLabel(for: bucket, range: range)) · \(Self.compactTokens(bucket.totalTokens)) tokens"
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
