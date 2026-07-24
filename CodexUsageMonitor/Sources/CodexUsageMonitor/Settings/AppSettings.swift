import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let alertsEnabled = "alertsEnabled"
        static let thresholdWarnings = "notification.thresholdWarnings"
        /// Legacy global remaining-quota thresholds. Superseded by the
        /// per-provider keys below; retained only as the migration source.
        static let enabledQuotaThresholds = "notification.enabledQuotaThresholds"
        static func enabledQuotaThresholds(for provider: AgentProvider) -> String {
            "notification.enabledQuotaThresholds.\(provider.rawValue)"
        }
        static let forecastWarnings = "notification.forecastWarnings"
        static let resetCreditWarnings = "notification.resetCreditWarnings"
        static let resetWarnings = "notification.resetWarnings"
        static let staleDataWarnings = "notification.staleDataWarnings"
        static let refreshFailureWarnings = "notification.refreshFailureWarnings"
        static let refreshMode = "refresh.mode"
        static let refreshOnWake = "refresh.onWake"
        static let menuBarDisplayStyle = "menuBar.displayStyle"
        static let quotaValueMode = "menuBar.valueMode"
        static let appearancePreference = "general.appearance"
        static let keyboardShortcutsEnabled = "general.keyboardShortcutsEnabled"
        static let claudeCLIProbeConsented = "claude.cliProbeConsented"
        static let claudeSetupHistory = "claude.hasSetupHistory"
        static let selectedMenuProvider = "menu.selectedProvider"
    }

    private let defaults: UserDefaults

    @Published var selectedSettingsTab: SettingsTab = .notifications
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown
    @Published var alertsEnabled: Bool { didSet { defaults.set(alertsEnabled, forKey: Key.alertsEnabled) } }
    /// Remaining-quota thresholds per provider. Each supported agent owns its
    /// own set so a user can, e.g., alert at 25% for Codex but 10% for Claude.
    @Published private(set) var enabledQuotaThresholdsByProvider: [AgentProvider: Set<RemainingQuotaThreshold>] {
        didSet { persistQuotaThresholds() }
    }
    @Published var forecastWarningsEnabled: Bool { didSet { defaults.set(forecastWarningsEnabled, forKey: Key.forecastWarnings) } }
    @Published var resetCreditWarningsEnabled: Bool { didSet { defaults.set(resetCreditWarningsEnabled, forKey: Key.resetCreditWarnings) } }
    @Published var resetWarningsEnabled: Bool { didSet { defaults.set(resetWarningsEnabled, forKey: Key.resetWarnings) } }
    @Published var staleDataWarningsEnabled: Bool { didSet { defaults.set(staleDataWarningsEnabled, forKey: Key.staleDataWarnings) } }
    @Published var refreshFailureWarningsEnabled: Bool { didSet { defaults.set(refreshFailureWarningsEnabled, forKey: Key.refreshFailureWarnings) } }
    @Published var refreshMode: RefreshMode { didSet { defaults.set(refreshMode.rawValue, forKey: Key.refreshMode) } }
    @Published var refreshOnWake: Bool { didSet { defaults.set(refreshOnWake, forKey: Key.refreshOnWake) } }
    @Published var menuBarDisplayStyle: MenuBarDisplayStyle { didSet { defaults.set(menuBarDisplayStyle.rawValue, forKey: Key.menuBarDisplayStyle) } }
    @Published var quotaValueMode: QuotaValueMode { didSet { defaults.set(quotaValueMode.rawValue, forKey: Key.quotaValueMode) } }
    @Published var appearancePreference: AppearancePreference { didSet { defaults.set(appearancePreference.rawValue, forKey: Key.appearancePreference) } }
    @Published var keyboardShortcutsEnabled: Bool { didSet { defaults.set(keyboardShortcutsEnabled, forKey: Key.keyboardShortcutsEnabled) } }
    /// The menu-bar popover tab the user last viewed. Stored raw; whether it is
    /// still a *supported* provider is resolved at the point of use
    /// (`MenuPopoverProviderCatalog.resolvedSelection`), so a supported provider
    /// with no current snapshot stays selected while an unsupported one falls
    /// back to Codex.
    @Published var selectedMenuProvider: AgentProvider { didSet { defaults.set(selectedMenuProvider.rawValue, forKey: Key.selectedMenuProvider) } }
    /// Whether the user has acknowledged that the CLI usage probe costs
    /// tokens. Gates the confirmation prompt so it appears on first use, not
    /// on every press.
    @Published var claudeCLIProbeConsented: Bool { didSet { defaults.set(claudeCLIProbeConsented, forKey: Key.claudeCLIProbeConsented) } }
    @Published private(set) var hasClaudeSetupHistory: Bool {
        didSet { defaults.set(hasClaudeSetupHistory, forKey: Key.claudeSetupHistory) }
    }

    init(
        defaults: UserDefaults = .standard,
        legacyClaudeSetupEvidence: Bool = false
    ) {
        self.defaults = defaults
        alertsEnabled = defaults.bool(forKey: Key.alertsEnabled)
        // Defaults false: the user must opt in before the CLI is ever run.
        claudeCLIProbeConsented = defaults.bool(forKey: Key.claudeCLIProbeConsented)
        hasClaudeSetupHistory = defaults.bool(forKey: Key.claudeSetupHistory)
            || legacyClaudeSetupEvidence
        if legacyClaudeSetupEvidence {
            defaults.set(true, forKey: Key.claudeSetupHistory)
        }
        enabledQuotaThresholdsByProvider = Self.quotaThresholdsByProvider(defaults: defaults)
        forecastWarningsEnabled = Self.value(for: Key.forecastWarnings, defaults: defaults, defaultValue: true)
        resetCreditWarningsEnabled = Self.value(for: Key.resetCreditWarnings, defaults: defaults, defaultValue: true)
        resetWarningsEnabled = Self.value(for: Key.resetWarnings, defaults: defaults, defaultValue: true)
        staleDataWarningsEnabled = Self.value(for: Key.staleDataWarnings, defaults: defaults, defaultValue: true)
        refreshFailureWarningsEnabled = Self.value(for: Key.refreshFailureWarnings, defaults: defaults, defaultValue: true)
        let storedRefreshMode = defaults.string(forKey: Key.refreshMode)
        if storedRefreshMode == "one-minute" {
            refreshMode = .ninetySeconds
            defaults.set(RefreshMode.ninetySeconds.rawValue, forKey: Key.refreshMode)
        } else {
            refreshMode = storedRefreshMode.flatMap(RefreshMode.init(rawValue:)) ?? .twoMinutes
        }
        refreshOnWake = Self.value(for: Key.refreshOnWake, defaults: defaults, defaultValue: true)
        menuBarDisplayStyle = defaults.string(forKey: Key.menuBarDisplayStyle).flatMap(MenuBarDisplayStyle.init(rawValue:)) ?? .gaugeAndLowest
        quotaValueMode = defaults.string(forKey: Key.quotaValueMode).flatMap(QuotaValueMode.init(rawValue:)) ?? .remaining
        appearancePreference = defaults.string(forKey: Key.appearancePreference).flatMap(AppearancePreference.init(rawValue:)) ?? .system
        keyboardShortcutsEnabled = Self.value(for: Key.keyboardShortcutsEnabled, defaults: defaults, defaultValue: true)
        selectedMenuProvider = defaults.string(forKey: Key.selectedMenuProvider)
            .flatMap(AgentProvider.init(rawValue:)) ?? .codex
        // Seed per-provider keys on first run / migration so the store is
        // durable from the start.
        persistQuotaThresholds()
    }

    /// Providers that have remaining-quota windows and therefore threshold
    /// alerts. Copilot has no personal quota, so it is excluded. `nonisolated`
    /// so pure helpers (e.g. confirmation copy) can read the canonical order.
    nonisolated static let quotaThresholdProviders: [AgentProvider] = [.codex, .claudeCode]

    private static func value(for key: String, defaults: UserDefaults, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    /// Loads each provider's thresholds, migrating any pre-existing global set
    /// into every supported provider so an upgrade loses no user choice.
    private static func quotaThresholdsByProvider(defaults: UserDefaults) -> [AgentProvider: Set<RemainingQuotaThreshold>] {
        let legacyGlobal = legacyGlobalThresholds(defaults: defaults)
        var result: [AgentProvider: Set<RemainingQuotaThreshold>] = [:]
        for provider in quotaThresholdProviders {
            if let stored = thresholds(forKey: Key.enabledQuotaThresholds(for: provider), defaults: defaults) {
                result[provider] = stored
            } else {
                // First run for this provider key: inherit the migrated global set.
                result[provider] = legacyGlobal
            }
        }
        return result
    }

    private static func legacyGlobalThresholds(defaults: UserDefaults) -> Set<RemainingQuotaThreshold> {
        if let stored = thresholds(forKey: Key.enabledQuotaThresholds, defaults: defaults) {
            return stored
        }
        let legacyEnabled = value(for: Key.thresholdWarnings, defaults: defaults, defaultValue: true)
        return legacyEnabled ? Set(RemainingQuotaThreshold.allCases) : []
    }

    private static func thresholds(forKey key: String, defaults: UserDefaults) -> Set<RemainingQuotaThreshold>? {
        guard let rawValues = defaults.array(forKey: key) else { return nil }
        return Set(rawValues.compactMap { value in
            (value as? NSNumber).flatMap { RemainingQuotaThreshold(rawValue: $0.intValue) }
        })
    }

    private func persistQuotaThresholds() {
        for provider in Self.quotaThresholdProviders {
            let thresholds = enabledQuotaThresholdsByProvider[provider] ?? []
            defaults.set(
                thresholds.map(\.rawValue).sorted(by: >),
                forKey: Key.enabledQuotaThresholds(for: provider)
            )
        }
    }

    func isQuotaThresholdEnabled(_ threshold: RemainingQuotaThreshold, for provider: AgentProvider) -> Bool {
        enabledQuotaThresholdsByProvider[provider]?.contains(threshold) ?? false
    }

    func setQuotaThreshold(_ threshold: RemainingQuotaThreshold, enabled: Bool, for provider: AgentProvider) {
        var thresholds = enabledQuotaThresholdsByProvider[provider] ?? []
        if enabled {
            thresholds.insert(threshold)
        } else {
            thresholds.remove(threshold)
        }
        enabledQuotaThresholdsByProvider[provider] = thresholds
    }

    func updateNotificationAuthorization(_ state: NotificationAuthorizationState) {
        notificationAuthorizationState = state
        if state == .denied || state == .unavailable {
            alertsEnabled = false
        }
    }

    /// Monotonic by design: losing a credential or deleting cached usage
    /// makes Claude lapsed, not first-run again.
    func recordClaudeSetupHistory() {
        guard !hasClaudeSetupHistory else { return }
        hasClaudeSetupHistory = true
    }

    /// Migrates builds that predate `claude.hasSetupHistory` using only
    /// app-owned, non-secret files. Claude Code's Keychain item is deliberately
    /// not probed in the background because that could raise an ACL prompt.
    static func hasLegacyClaudeSetupEvidence(
        applicationSupportDirectory: URL? = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let directory = applicationSupportDirectory?
            .appendingPathComponent("CodexUsageMonitor", isDirectory: true)
        else { return false }
        return [
            "claude-usage-cache.json",
            "claude-rate-limits.json",
        ].contains {
            fileManager.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }
}
