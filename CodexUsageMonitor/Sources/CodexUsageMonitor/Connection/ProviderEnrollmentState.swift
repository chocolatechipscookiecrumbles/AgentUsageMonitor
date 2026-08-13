import Foundation

/// Whether the user has explicitly asked this app to monitor a provider.
///
/// This is app-local consent and nothing else. It is never inferred from CLI
/// availability, a cached quota file, a local record directory, or a Keychain
/// item: 0.0.1 adopted whatever session it found, so a user who had only ever
/// signed in to the Codex CLI arrived at a first launch that was already
/// reading and displaying their account.
enum ProviderEnrollmentState: String, Codable, Equatable, Sendable {
    /// No choice has been recorded. The provider's tab is connect-only and none
    /// of its owners run. This is also where a 0.0.1 upgrade lands, because that
    /// build stored no explicit consent to migrate.
    case notRequested
    /// The user selected Connect for this provider.
    case enabled
    /// The user disconnected this provider inside the app. Kept distinct from
    /// `.notRequested` so a deliberate disconnect is never mistaken for a fresh
    /// install, and so a future migration can tell the two apart.
    case disabled
}

/// What one provider's runtime owners are permitted to do right now.
///
/// Derived from enrollment plus the existing Token Monitor visibility
/// preference; it persists nothing of its own. Enrollment is the gate that
/// permits an owner to start — it does not merge quota, connection, and local
/// activity into one state, and those three keep their separate models.
struct ProviderRuntimePolicy: Equatable, Sendable {
    let mayCheckAccount: Bool
    let mayRefreshQuota: Bool
    let mayCollectLocalActivity: Bool
    let showsConnectOnly: Bool

    static func resolve(
        enrollment: ProviderEnrollmentState,
        isTokenMonitorVisible: Bool
    ) -> Self {
        let enrolled = enrollment == .enabled
        return Self(
            mayCheckAccount: enrolled,
            mayRefreshQuota: enrolled,
            // Local reads need consent *and* the user's existing card
            // preference. Once enrolled the two stay independent: a quota
            // sign-in failure must not stop a valid local read, and a missing
            // local record must not read as an authentication failure.
            mayCollectLocalActivity: enrolled && isTokenMonitorVisible,
            showsConnectOnly: !enrolled
        )
    }
}
