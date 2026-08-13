import Foundation

/// How one provider's tab presents itself.
///
/// Derived from enrollment first and provider state second, so cached quota,
/// a still-valid CLI session, or a previously written local-activity file can
/// never promote an unenrolled tab into an operational one.
enum ProviderMenuMode: Equatable, Sendable {
    /// No explicit Connect action has been taken. The tab shows its header, one
    /// Connect card, and the shared footer — no quota, cached strip, Token
    /// Monitor, recovery furniture, or notification strip.
    case connectOnly
    /// The user enrolled this provider. Its existing connection, refresh, and
    /// recovery states own the presentation from here.
    case operational

    static func resolve(policy: ProviderRuntimePolicy) -> Self {
        policy.showsConnectOnly ? .connectOnly : .operational
    }
}
