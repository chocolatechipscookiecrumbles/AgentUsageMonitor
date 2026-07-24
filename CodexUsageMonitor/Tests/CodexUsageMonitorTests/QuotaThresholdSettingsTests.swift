import XCTest
@testable import CodexUsageMonitor

/// Remaining-quota thresholds are stored per provider, migrate cleanly from the
/// old global key, and each provider's set is independent.
@MainActor
final class QuotaThresholdSettingsTests: XCTestCase {
    // Durable key strings the migration must honor (private in AppSettings).
    private let legacyGlobalKey = "notification.enabledQuotaThresholds"
    private let legacyBoolKey = "notification.thresholdWarnings"

    func testPerProviderSetIsIndependentAndPersists() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            // Both providers default to all thresholds on. Toggle one threshold
            // in opposite directions per provider to prove independence.
            settings.setQuotaThreshold(.ten, enabled: false, for: .codex)
            settings.setQuotaThreshold(.fifty, enabled: false, for: .claudeCode)

            XCTAssertFalse(settings.isQuotaThresholdEnabled(.ten, for: .codex))
            XCTAssertTrue(settings.isQuotaThresholdEnabled(.ten, for: .claudeCode), "Codex change must not affect Claude")
            XCTAssertFalse(settings.isQuotaThresholdEnabled(.fifty, for: .claudeCode))
            XCTAssertTrue(settings.isQuotaThresholdEnabled(.fifty, for: .codex), "Claude change must not affect Codex")

            // Round-trips across instances.
            let reloaded = AppSettings(defaults: defaults)
            XCTAssertFalse(reloaded.isQuotaThresholdEnabled(.ten, for: .codex))
            XCTAssertTrue(reloaded.isQuotaThresholdEnabled(.ten, for: .claudeCode))
            XCTAssertFalse(reloaded.isQuotaThresholdEnabled(.fifty, for: .claudeCode))
            XCTAssertTrue(reloaded.isQuotaThresholdEnabled(.fifty, for: .codex))
        }
    }

    /// A pre-existing global set (from before per-agent thresholds) must seed
    /// every supported provider so no user choice is lost on upgrade.
    func testGlobalSetMigratesIntoEveryProvider() {
        withDefaults { defaults in
            defaults.set([25, 10], forKey: legacyGlobalKey)

            let settings = AppSettings(defaults: defaults)

            for provider in AppSettings.quotaThresholdProviders {
                XCTAssertTrue(settings.isQuotaThresholdEnabled(.twentyFive, for: provider), "\(provider) missing migrated 25%")
                XCTAssertTrue(settings.isQuotaThresholdEnabled(.ten, for: provider), "\(provider) missing migrated 10%")
                XCTAssertFalse(settings.isQuotaThresholdEnabled(.fifty, for: provider), "\(provider) gained an unset threshold")
            }
        }
    }

    /// The oldest builds stored only a boolean; enabled means all thresholds on.
    func testLegacyBooleanMigratesToAllThresholds() {
        withDefaults { defaults in
            defaults.set(true, forKey: legacyBoolKey)

            let settings = AppSettings(defaults: defaults)

            for provider in AppSettings.quotaThresholdProviders {
                for threshold in RemainingQuotaThreshold.allCases {
                    XCTAssertTrue(settings.isQuotaThresholdEnabled(threshold, for: provider))
                }
            }
        }
    }

    private func withDefaults(_ operation: (UserDefaults) -> Void) {
        let suiteName = "QuotaThresholdSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        operation(defaults)
    }
}
