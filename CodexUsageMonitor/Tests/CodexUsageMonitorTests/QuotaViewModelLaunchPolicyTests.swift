import XCTest
@testable import CodexUsageMonitor

@MainActor
final class QuotaViewModelLaunchPolicyTests: XCTestCase {
    func testWindowPopoverGateDoesNotStartProviderMonitoring() {
        XCTAssertFalse(
            QuotaViewModel.shouldStartProviderMonitoring(
                arguments: ["CodexUsageMonitor", MenuPopoverViabilityGate.launchArgument]
            )
        )
    }

    func testOnboardingPreviewDoesNotStartProviderMonitoring() {
        XCTAssertFalse(
            QuotaViewModel.shouldStartProviderMonitoring(
                arguments: ["CodexUsageMonitor", OnboardingLaunchMode.previewArgument]
            )
        )
    }

    /// The released 0.0.1 defect: a fresh installation had no key recording
    /// consent, both disconnect booleans read `false`, and every provider owner
    /// started anyway. Absent enrollment must deny account reads, quota
    /// collection, and local scans for both providers.
    func testFreshInstallationPermitsNoProviderWork() throws {
        let defaults = try makeIsolatedDefaults()
        let enrollment = ProviderEnrollmentStore(defaults: defaults)

        for provider in [AgentProvider.codex, .claudeCode] {
            XCTAssertEqual(enrollment.state(for: provider), .notRequested)
            // Token Monitor visibility defaults to true, so this is the exact
            // combination that used to read records on first launch.
            let policy = ProviderRuntimePolicy.resolve(
                enrollment: enrollment.state(for: provider),
                isTokenMonitorVisible: true
            )
            XCTAssertFalse(policy.mayCheckAccount)
            XCTAssertFalse(policy.mayRefreshQuota)
            XCTAssertFalse(policy.mayCollectLocalActivity)
            XCTAssertTrue(policy.showsConnectOnly)
        }
    }

    /// An upgrade from 0.0.1 carries `codex.disconnected` / `claude.disconnected`
    /// set to `false`. That is the same value a user who never opened the app
    /// would have, so it is not consent and must not migrate to `.enabled`.
    func testLegacyDisconnectFlagsAreNotTreatedAsConsent() throws {
        let defaults = try makeIsolatedDefaults()
        defaults.set(false, forKey: "codex.disconnected")
        defaults.set(false, forKey: "claude.disconnected")

        let enrollment = ProviderEnrollmentStore(defaults: defaults)

        XCTAssertEqual(enrollment.state(for: .codex), .notRequested)
        XCTAssertEqual(enrollment.state(for: .claudeCode), .notRequested)
        XCTAssertNil(defaults.object(forKey: "codex.disconnected"))
        XCTAssertNil(defaults.object(forKey: "claude.disconnected"))
    }

    /// Reading enrollment on launch must not write a default. If it did, a user
    /// who merely opened the app would acquire a stored decision they never made.
    func testReadingEnrollmentPersistsNothing() throws {
        let defaults = try makeIsolatedDefaults()
        let enrollment = ProviderEnrollmentStore(defaults: defaults)

        _ = enrollment.state(for: .codex)
        _ = enrollment.state(for: .claudeCode)

        XCTAssertNil(defaults.object(forKey: "provider.enrollment.codex"))
        XCTAssertNil(defaults.object(forKey: "provider.enrollment.claude-code"))
    }

    /// Connecting one provider must not enroll the other, and a disconnect must
    /// stay distinguishable from "never asked" so a later migration can tell
    /// a deliberate opt-out from a fresh install.
    func testEnrollmentIsIndependentPerProviderAndSurvivesReload() throws {
        let defaults = try makeIsolatedDefaults()
        let enrollment = ProviderEnrollmentStore(defaults: defaults)

        enrollment.enable(.codex)

        XCTAssertEqual(enrollment.state(for: .codex), .enabled)
        XCTAssertEqual(enrollment.state(for: .claudeCode), .notRequested)

        enrollment.disable(.codex)
        let reloaded = ProviderEnrollmentStore(defaults: defaults)

        XCTAssertEqual(reloaded.state(for: .codex), .disabled)
        XCTAssertEqual(reloaded.state(for: .claudeCode), .notRequested)
    }

    /// Dismissing the tour records acknowledgement and nothing else. The
    /// released report was that setup felt like it had connected something;
    /// these two facts must stay separable.
    func testAcknowledgingOnboardingDoesNotEnrollAnyProvider() throws {
        let defaults = try makeIsolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        let enrollment = ProviderEnrollmentStore(defaults: defaults)
        XCTAssertTrue(settings.needsOnboarding)

        settings.acknowledgeCurrentOnboarding()

        XCTAssertFalse(settings.needsOnboarding)
        XCTAssertEqual(enrollment.state(for: .codex), .notRequested)
        XCTAssertEqual(enrollment.state(for: .claudeCode), .notRequested)
        XCTAssertFalse(AppSettings(defaults: defaults).needsOnboarding)
    }

    private func makeIsolatedDefaults() throws -> UserDefaults {
        let suite = "CodexUsageMonitorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return defaults
    }
}
