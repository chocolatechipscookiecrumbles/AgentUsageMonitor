import Foundation

actor CodexQuotaCollector {
    private let locator: CodexExecutableLocator
    private let stateStore: QuotaStateStore

    init(locator: CodexExecutableLocator = CodexExecutableLocator(), stateStore: QuotaStateStore = QuotaStateStore()) {
        self.locator = locator
        self.stateStore = stateStore
    }

    func refresh() async -> QuotaPresentation {
        do {
            let executable = try locator.locate()
            var samples: [CodexQuotaSample] = []
            for attempt in 0..<3 {
                samples.append(try CodexAppServerSession().collectSample(codexExecutable: executable))
                if attempt < 2 {
                    try await Task.sleep(for: .seconds(1))
                }
            }
            return resolve(samples: samples)
        } catch {
            return QuotaPresentation.unavailable(error.localizedDescription)
        }
    }

    private func resolve(samples: [CodexQuotaSample]) -> QuotaPresentation {
        let accepted = samples.filter { !QuotaValidator.isTransientEmpty($0) }
        if accepted.count >= 2, QuotaValidator.allMatch(accepted), let latest = accepted.last {
            let confirmation: ConfirmationState = accepted.count == samples.count ? .confirmed : .confirmedAfterRetry
            let presentation = latest.presentation(confirmation: confirmation, source: "live")
            stateStore.save(presentation)
            return presentation
        }
        guard let latest = accepted.last ?? samples.last else {
            return .unavailable("Codex did not return a quota snapshot.")
        }
        if let cached = stateStore.load()?.presentation, QuotaValidator.matchesCache(cached, sample: latest) {
            return QuotaPresentation(
                accountFingerprint: cached.accountFingerprint,
                limitID: cached.limitID,
                planType: cached.planType,
                creditBalance: cached.creditBalance,
                hasCredits: cached.hasCredits,
                availableResetCredits: cached.availableResetCredits,
                resetCreditExpiryDates: cached.resetCreditExpiryDates,
                fiveHour: cached.fiveHour,
                weekly: cached.weekly,
                confirmation: .cachedLastKnownGood,
                collectedAt: cached.collectedAt,
                source: "last-known-good",
                detail: "Fresh Codex samples were transient or inconsistent; showing the last confirmed result."
            )
        }
        let detail = accepted.isEmpty
            ? "All fresh Codex samples matched the observed transient empty-snapshot pattern."
            : "Fresh Codex samples did not agree closely enough to be confirmed."
        return latest.presentation(confirmation: .unconfirmed, source: "live", detail: detail)
    }
}
