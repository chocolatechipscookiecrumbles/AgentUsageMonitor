import Foundation

/// Display inputs only. Building a diagnostic snapshot never constructs a monitor,
/// settings store, credential controller, or enrollment store.
struct MenuContentSnapshot {
    let provider: AgentProvider
    let mode: ProviderMenuMode
    let header: MenuProviderHeaderPresentation
    let isRefreshing: Bool
    let codexPresentation: CodexMenuPresentation?
    let codexConnection: AgentConnectionState
    let claudeModel: ClaudeUsageDisplayModel?
    let claudeConnection: ClaudeConnectionState
    let claudeStatus: ClaudeConnectionStatus
    let activity: ProviderTokenActivityPresentation?
    let visibleActivitySections: Set<TokenMonitorSection>
    let showsNotificationPermission: Bool

    @MainActor
    static func live(_ viewModel: QuotaViewModel, provider: AgentProvider) -> Self {
        let mode = ProviderMenuMode.resolve(policy: viewModel.runtimePolicy(for: provider))
        let isRefreshing: Bool = switch provider {
        case .codex: viewModel.isRefreshing
        case .claudeCode: viewModel.isRefreshingClaude || viewModel.isRunningClaudeCLIProbe
        case .githubCopilot: false
        }
        let header: MenuProviderHeaderPresentation = if mode == .connectOnly {
            .connectOnly(provider: provider)
        } else {
            switch provider {
            case .codex, .githubCopilot:
                .codex(displayState: viewModel.displayState,
                       connectionState: viewModel.connectionState,
                       isRefreshing: isRefreshing)
            case .claudeCode:
                .claude(usageState: viewModel.claudeState,
                        connectionState: viewModel.claudeConnectionState,
                        isRefreshing: isRefreshing)
            }
        }
        let settings = viewModel.settings
        let activity = settings.isTokenMonitorVisible(for: provider)
            ? ProviderTokenActivityPresentation(
                provider: provider,
                state: viewModel.localActivityState(for: provider),
                range: settings.tokenMonitorRange(for: provider)
            ) : nil
        return Self(
            provider: provider,
            mode: mode,
            header: header,
            isRefreshing: isRefreshing,
            codexPresentation: CodexMenuPresentation(
                displayState: viewModel.displayState,
                fiveHourForecast: viewModel.fiveHourForecast,
                weeklyForecast: viewModel.weeklyForecast
            ),
            codexConnection: viewModel.connectionState,
            claudeModel: viewModel.claudeState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) },
            claudeConnection: viewModel.claudeConnectionState,
            claudeStatus: ClaudeConnectionStatus.resolve(
                isEnrolled: viewModel.enrollment.isEnabled(.claudeCode),
                signInState: viewModel.claudeConnectionState,
                usageState: viewModel.claudeState
            ),
            activity: activity,
            visibleActivitySections: settings.enabledTokenMonitorSections(for: provider),
            showsNotificationPermission: viewModel.notificationAuthorizationState == .denied
        )
    }

    static func fixture(provider: AgentProvider, index: Int, now: Date = .now) -> Self {
        let labels = fixtureLabels(for: provider)
        let stage = index % labels.count
        let mode: ProviderMenuMode = provider == .githubCopilot
            || (provider == .claudeCode && stage == 2) ? .connectOnly : .operational
        let cached = provider == .codex && (stage == 2 || stage == 3)
        let hasCodexReading = provider == .codex && stage != 4
        let codexConnection: AgentConnectionState = provider == .codex && stage == 3
            ? .failed(.appServerUnavailable)
            : .connected(AgentAccountSummary(planType: "Plus"))
        let codexState = fixtureCodexState(
            hasReading: hasCodexReading,
            cached: cached,
            repeatedFailure: stage == 3,
            recovered: stage == 5,
            now: now
        )
        let claudeConnection: ClaudeConnectionState = .connected(
            ClaudeAccountSummary(planType: "Max")
        )
        let claudeState = fixtureClaudeState(tall: stage == 1, now: now)
        let isRefreshing = provider == .codex && stage == 1
        let activity: ProviderTokenActivityPresentation? = switch provider {
        case .codex where stage == 0 || stage == 2 || stage == 3 || stage == 4 || stage == 5,
             .claudeCode where stage == 1:
            fixtureActivity(provider: provider, now: now)
        default: nil
        }
        let header: MenuProviderHeaderPresentation = if mode == .connectOnly {
            .connectOnly(provider: provider)
        } else if provider == .claudeCode {
            .claude(usageState: claudeState,
                    connectionState: claudeConnection,
                    isRefreshing: false,
                    now: now)
        } else {
            .codex(displayState: codexState,
                   connectionState: codexConnection,
                   isRefreshing: isRefreshing)
        }
        return Self(
            provider: provider,
            mode: mode,
            header: header,
            isRefreshing: isRefreshing,
            codexPresentation: CodexMenuPresentation(
                displayState: codexState,
                fiveHourForecast: nil,
                weeklyForecast: nil
            ),
            codexConnection: codexConnection,
            claudeModel: claudeState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) },
            claudeConnection: claudeConnection,
            claudeStatus: ClaudeConnectionStatus.resolve(
                isEnrolled: mode == .operational,
                signInState: claudeConnection,
                usageState: claudeState
            ),
            activity: activity,
            visibleActivitySections: Set(TokenMonitorSection.allCases),
            showsNotificationPermission: provider == .codex && stage == 3
        )
    }

    static func fixtureLabels(for provider: AgentProvider) -> [String] {
        switch provider {
        case .codex:
            ["Confirmed, credits and activity", "Refreshing", "Initial cached failure",
             "Repeated failure, cached and warning", "Unavailable with activity", "Confirmed recovery"]
        case .claudeCode:
            ["Shortest reading", "Tall reading and activity", "Connect only"]
        case .githubCopilot:
            ["Connect only"]
        }
    }

    private static func fixtureCodexState(
        hasReading: Bool,
        cached: Bool,
        repeatedFailure: Bool,
        recovered: Bool,
        now: Date
    ) -> QuotaDisplayState {
        let presentation = QuotaPresentation(
            accountFingerprint: nil,
            limitID: nil,
            planType: "Plus",
            creditBalance: "12.3456",
            hasCredits: true,
            availableResetCredits: 2,
            resetCreditExpiryDates: [now.addingTimeInterval(3_600), now.addingTimeInterval(86_400)],
            fiveHour: QuotaWindow(usedPercent: 78, resetAt: now.addingTimeInterval(3_600), durationMinutes: 300),
            weekly: QuotaWindow(usedPercent: 92, resetAt: now.addingTimeInterval(86_400), durationMinutes: 10_080),
            confirmation: !hasReading ? .unavailable
                : (cached ? .cachedLastKnownGood : (recovered ? .confirmedAfterRetry : .confirmed)),
            collectedAt: now.addingTimeInterval(cached ? -3_600 : -120),
            source: "fixture",
            detail: nil
        )
        return QuotaDisplayState(
            mode: cached || !hasReading ? .cachedPaused : .confirmedCompleted,
            displayedRecord: hasReading ? .withoutForecasts(presentation) : nil,
            lastAttemptAt: now,
            lastConfirmedAt: hasReading ? presentation.collectedAt : nil,
            pauseReason: !hasReading ? .unavailable
                : (cached ? (repeatedFailure ? .repeatedFailures : .cachedLastKnownGood) : nil)
        )
    }

    private static func fixtureClaudeState(tall: Bool, now: Date) -> ClaudeUsageState {
        let snapshot = ClaudeUsageSnapshot(
            planHint: "Max",
            fiveHour: tall ? ClaudeLimitWindow(usedPercent: 82, resetsAt: now.addingTimeInterval(2_400)) : nil,
            sevenDay: ClaudeLimitWindow(usedPercent: 64, resetsAt: now.addingTimeInterval(86_400)),
            scopedWindows: [],
            extraUsage: tall ? ClaudeExtraUsage(isEnabled: true, monthlyLimit: 100, usedCredits: 58.25, currencyCode: "USD") : nil,
            source: tall ? .cache : .oauth,
            capturedAt: now.addingTimeInterval(tall ? -3_600 : -120),
            schemaVersion: 1
        )
        return .available(ClaudeUsagePresentation(
            snapshot: snapshot,
            delivery: tall ? .cached : .live,
            warnings: tall ? ["Live usage is temporarily unavailable. Showing the last saved reading while you reconnect."] : []
        ))
    }

    private static func fixtureActivity(
        provider: AgentProvider,
        now: Date
    ) -> ProviderTokenActivityPresentation? {
        guard let total = LocalActivityTokenBreakdown(
            provider: provider,
            inputTokens: 12_500,
            cacheCreationTokens: provider == .claudeCode ? 500 : nil,
            cachedInputTokens: 3_000,
            outputTokens: 2_500,
            reasoningOutputTokens: provider == .codex ? 700 : nil
        ), let requestTokens = LocalActivityTokenBreakdown(
            provider: provider,
            inputTokens: 900,
            cacheCreationTokens: provider == .claudeCode ? 100 : nil,
            cachedInputTokens: 200,
            outputTokens: 300,
            reasoningOutputTokens: provider == .codex ? 100 : nil
        ) else { return nil }

        let intervalStart = now.addingTimeInterval(-5_400)
        let bucketTotals: [Int64] = provider == .claudeCode
            ? [5_000, 6_500, 7_000] : [4_000, 6_000, 5_000]
        let buckets = bucketTotals.enumerated().map { index, tokens in
            let start = intervalStart.addingTimeInterval(Double(index) * 1_800)
            return LocalActivityBucket(
                id: start,
                startedAt: start,
                endedAt: start.addingTimeInterval(1_800),
                totalTokens: tokens
            )
        }
        let lastRequest = LocalActivityRequest(
            id: "diagnostic-last-request",
            provider: provider,
            occurredAt: now.addingTimeInterval(-600),
            modelID: provider == .codex ? "gpt-5.1-codex" : "claude-sonnet-4-5",
            tokens: requestTokens
        )
        let modelTotals: [Int64] = provider == .claudeCode
            ? [9_500, 6_000, 3_000] : [8_000, 5_000, 2_000]
        let modelNames = ["Primary", "Fast", "Other"]
        return ProviderTokenActivityPresentation(
            provider: provider,
            state: .available(ProviderLocalActivitySnapshot(
                provider: provider,
                range: .day,
                rangeStartedAt: Calendar.current.startOfDay(for: now),
                generatedAt: now,
                rangeTokens: total,
                requestCount: 18,
                buckets: buckets,
                modelUsage: zip(modelNames, modelTotals).map { name, tokens in
                    LocalActivityModelShare(
                        shortName: name,
                        sourceModelIDs: [name.lowercased()],
                        totalTokens: tokens,
                        fraction: Double(tokens) / Double(total.totalTokens)
                    )
                },
                lastRequest: lastRequest
            )),
            now: now
        )
    }
}
