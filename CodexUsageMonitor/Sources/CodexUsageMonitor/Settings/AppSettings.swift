import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let alertsEnabled = "alertsEnabled"
        static let thresholdWarnings = "notification.thresholdWarnings"
        static let enabledQuotaThresholds = "notification.enabledQuotaThresholds"
        static let forecastWarnings = "notification.forecastWarnings"
        static let resetCreditWarnings = "notification.resetCreditWarnings"
        static let resetWarnings = "notification.resetWarnings"
        static let staleDataWarnings = "notification.staleDataWarnings"
        static let refreshFailureWarnings = "notification.refreshFailureWarnings"
        static let quietHoursEnabled = "notification.quietHoursEnabled"
        static let quietHoursStartMinutes = "notification.quietHoursStartMinutes"
        static let quietHoursEndMinutes = "notification.quietHoursEndMinutes"
        static let allowCriticalDuringQuietHours = "notification.allowCriticalDuringQuietHours"
        static let refreshMode = "refresh.mode"
        static let menuBarDisplayStyle = "menuBar.displayStyle"
        static let quotaValueMode = "menuBar.valueMode"
        static let appearancePreference = "general.appearance"
        static let keyboardShortcutsEnabled = "general.keyboardShortcutsEnabled"
    }

    private let defaults: UserDefaults

    @Published var selectedSettingsTab: SettingsTab = .notifications
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown
    @Published var alertsEnabled: Bool { didSet { defaults.set(alertsEnabled, forKey: Key.alertsEnabled) } }
    @Published private(set) var enabledQuotaThresholds: Set<RemainingQuotaThreshold> {
        didSet {
            defaults.set(
                enabledQuotaThresholds.map(\.rawValue).sorted(by: >),
                forKey: Key.enabledQuotaThresholds
            )
        }
    }
    @Published var forecastWarningsEnabled: Bool { didSet { defaults.set(forecastWarningsEnabled, forKey: Key.forecastWarnings) } }
    @Published var resetCreditWarningsEnabled: Bool { didSet { defaults.set(resetCreditWarningsEnabled, forKey: Key.resetCreditWarnings) } }
    @Published var resetWarningsEnabled: Bool { didSet { defaults.set(resetWarningsEnabled, forKey: Key.resetWarnings) } }
    @Published var staleDataWarningsEnabled: Bool { didSet { defaults.set(staleDataWarningsEnabled, forKey: Key.staleDataWarnings) } }
    @Published var refreshFailureWarningsEnabled: Bool { didSet { defaults.set(refreshFailureWarningsEnabled, forKey: Key.refreshFailureWarnings) } }
    @Published var quietHoursEnabled: Bool { didSet { defaults.set(quietHoursEnabled, forKey: Key.quietHoursEnabled) } }
    @Published var quietHoursStartMinutes: Int { didSet { defaults.set(quietHoursStartMinutes, forKey: Key.quietHoursStartMinutes) } }
    @Published var quietHoursEndMinutes: Int { didSet { defaults.set(quietHoursEndMinutes, forKey: Key.quietHoursEndMinutes) } }
    @Published var allowCriticalDuringQuietHours: Bool { didSet { defaults.set(allowCriticalDuringQuietHours, forKey: Key.allowCriticalDuringQuietHours) } }
    @Published var refreshMode: RefreshMode { didSet { defaults.set(refreshMode.rawValue, forKey: Key.refreshMode) } }
    @Published var menuBarDisplayStyle: MenuBarDisplayStyle { didSet { defaults.set(menuBarDisplayStyle.rawValue, forKey: Key.menuBarDisplayStyle) } }
    @Published var quotaValueMode: QuotaValueMode { didSet { defaults.set(quotaValueMode.rawValue, forKey: Key.quotaValueMode) } }
    @Published var appearancePreference: AppearancePreference { didSet { defaults.set(appearancePreference.rawValue, forKey: Key.appearancePreference) } }
    @Published var keyboardShortcutsEnabled: Bool { didSet { defaults.set(keyboardShortcutsEnabled, forKey: Key.keyboardShortcutsEnabled) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        alertsEnabled = defaults.bool(forKey: Key.alertsEnabled)
        enabledQuotaThresholds = Self.quotaThresholds(defaults: defaults)
        forecastWarningsEnabled = Self.value(for: Key.forecastWarnings, defaults: defaults, defaultValue: true)
        resetCreditWarningsEnabled = Self.value(for: Key.resetCreditWarnings, defaults: defaults, defaultValue: true)
        resetWarningsEnabled = Self.value(for: Key.resetWarnings, defaults: defaults, defaultValue: true)
        staleDataWarningsEnabled = Self.value(for: Key.staleDataWarnings, defaults: defaults, defaultValue: true)
        refreshFailureWarningsEnabled = Self.value(for: Key.refreshFailureWarnings, defaults: defaults, defaultValue: true)
        quietHoursEnabled = defaults.bool(forKey: Key.quietHoursEnabled)
        quietHoursStartMinutes = Self.integer(for: Key.quietHoursStartMinutes, defaults: defaults, defaultValue: 22 * 60)
        quietHoursEndMinutes = Self.integer(for: Key.quietHoursEndMinutes, defaults: defaults, defaultValue: 7 * 60)
        allowCriticalDuringQuietHours = Self.value(for: Key.allowCriticalDuringQuietHours, defaults: defaults, defaultValue: true)
        refreshMode = defaults.string(forKey: Key.refreshMode).flatMap(RefreshMode.init(rawValue:)) ?? .twoMinutes
        menuBarDisplayStyle = defaults.string(forKey: Key.menuBarDisplayStyle).flatMap(MenuBarDisplayStyle.init(rawValue:)) ?? .gaugeAndLowest
        quotaValueMode = defaults.string(forKey: Key.quotaValueMode).flatMap(QuotaValueMode.init(rawValue:)) ?? .remaining
        appearancePreference = defaults.string(forKey: Key.appearancePreference).flatMap(AppearancePreference.init(rawValue:)) ?? .system
        keyboardShortcutsEnabled = Self.value(for: Key.keyboardShortcutsEnabled, defaults: defaults, defaultValue: true)
        if defaults.object(forKey: Key.enabledQuotaThresholds) == nil {
            defaults.set(
                enabledQuotaThresholds.map(\.rawValue).sorted(by: >),
                forKey: Key.enabledQuotaThresholds
            )
        }
    }

    private static func value(for key: String, defaults: UserDefaults, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    private static func integer(for key: String, defaults: UserDefaults, defaultValue: Int) -> Int {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.integer(forKey: key)
    }

    private static func quotaThresholds(defaults: UserDefaults) -> Set<RemainingQuotaThreshold> {
        if let rawValues = defaults.array(forKey: Key.enabledQuotaThresholds) {
            return Set(rawValues.compactMap { value in
                (value as? NSNumber).flatMap { RemainingQuotaThreshold(rawValue: $0.intValue) }
            })
        }
        let legacyEnabled = value(for: Key.thresholdWarnings, defaults: defaults, defaultValue: true)
        return legacyEnabled ? Set(RemainingQuotaThreshold.allCases) : []
    }

    func isQuotaThresholdEnabled(_ threshold: RemainingQuotaThreshold) -> Bool {
        enabledQuotaThresholds.contains(threshold)
    }

    func setQuotaThreshold(_ threshold: RemainingQuotaThreshold, enabled: Bool) {
        if enabled {
            enabledQuotaThresholds.insert(threshold)
        } else {
            enabledQuotaThresholds.remove(threshold)
        }
    }

    func updateNotificationAuthorization(_ state: NotificationAuthorizationState) {
        notificationAuthorizationState = state
        if state == .denied || state == .unavailable {
            alertsEnabled = false
        }
    }
}
