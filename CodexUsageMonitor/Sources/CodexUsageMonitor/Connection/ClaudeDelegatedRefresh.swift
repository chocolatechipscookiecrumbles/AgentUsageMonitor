import Foundation
import Security

/// A non-secret identity for Claude Code's Keychain item.
///
/// The modification date is readable with `kSecReturnAttributes` and **no**
/// `kSecReturnData`. Attributes are not ACL-gated: an unsigned process with no
/// grant of any kind reads them with `errSecSuccess` and no dialog (verified —
/// see `docs/development/claude-keychain-grant-durability.md`, O8). So this
/// detects that the credential changed without ever requesting the secret, and
/// can run on any refresh reason without risking a prompt.
struct ClaudeCredentialFingerprint: Equatable, Sendable {
    let modifiedAt: Date?
}

enum ClaudeDelegatedRefreshOutcome: Equatable, Sendable {
    /// Claude Code renewed its credential; the item changed.
    case refreshed
    /// The CLI ran cleanly but the credential is unchanged — nothing needed
    /// renewing, or Claude Code declined to.
    case notRefreshed
    case touchFailed
    case cliUnavailable
    case suppressedByCooldown
    /// Launching the provider CLI is a visible side effect, so automatic
    /// refreshes never do it.
    case notPermittedForReason
}

/// Asks **Claude Code** to renew its own OAuth credential, instead of this app
/// refreshing a borrowed token itself.
///
/// Motivation is an observed outage, not theory: a continuously running app
/// produced no Claude reading for about three hours because the borrowed access
/// token had expired, and the gap closed only when Claude Code next happened to
/// run and refresh it. The Keychain grant was intact throughout. Waiting for the
/// user to happen to use Claude Code is not a recovery strategy.
///
/// This runs **no token exchange**: no client ID, no `/v1/oauth/token`, no
/// authorization request, nothing presented under another application's
/// identity. Claude Code refreshes its own credential under its own identity,
/// and success is proven by the item's modification date changing.
actor ClaudeDelegatedRefreshCoordinator {
    /// Long enough that a failing touch cannot become a CLI-spawning loop, short
    /// enough that a user retrying after a minute is not stonewalled.
    static let cooldown: TimeInterval = 5 * 60

    private let isCLIAvailable: @Sendable () -> Bool
    private let readFingerprint: @Sendable () -> ClaudeCredentialFingerprint?
    private let touch: @Sendable () async throws -> Void
    private let now: @Sendable () -> Date

    private var lastAttemptAt: Date?
    private var inFlight: Task<ClaudeDelegatedRefreshOutcome, Never>?

    init(
        isCLIAvailable: @escaping @Sendable () -> Bool = { (try? ClaudeExecutableLocator().locate()) != nil },
        readFingerprint: @escaping @Sendable () -> ClaudeCredentialFingerprint? = {
            ClaudeDelegatedRefreshCoordinator.currentFingerprint()
        },
        touch: @escaping @Sendable () async throws -> Void = {
            try await ClaudeDelegatedRefreshCoordinator.runStatusTouch()
        },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.isCLIAvailable = isCLIAvailable
        self.readFingerprint = readFingerprint
        self.touch = touch
        self.now = now
    }

    func attempt(reason: ClaudeRefreshReason) async -> ClaudeDelegatedRefreshOutcome {
        // Spawning the provider CLI is user-visible. A timer must never do it,
        // for the same reason a timer must never raise a Keychain dialog.
        guard reason == .userInitiated else { return .notPermittedForReason }

        // A second caller joins the running attempt rather than launching the
        // CLI twice for one credential.
        if let inFlight { return await inFlight.value }

        if let lastAttemptAt, now().timeIntervalSince(lastAttemptAt) < Self.cooldown {
            return .suppressedByCooldown
        }
        guard isCLIAvailable() else { return .cliUnavailable }

        let task = Task<ClaudeDelegatedRefreshOutcome, Never> { [readFingerprint, touch] in
            let before = readFingerprint()
            do {
                try await touch()
            } catch {
                return .touchFailed
            }
            let after = readFingerprint()
            // "The command exited 0" is not evidence. The item changing is.
            return before != after ? .refreshed : .notRefreshed
        }
        inFlight = task
        lastAttemptAt = now()
        let outcome = await task.value
        inFlight = nil
        return outcome
    }

    /// Attribute-only read: never requests `kSecValueData`, so it cannot prompt
    /// and needs no grant.
    static func currentFingerprint(
        serviceName: String = "Claude Code-credentials"
    ) -> ClaudeCredentialFingerprint? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let attributes = item as? [String: Any]
        else { return nil }
        return ClaudeCredentialFingerprint(
            modifiedAt: attributes[kSecAttrModificationDate as String] as? Date
        )
    }

    /// Runs the Claude CLI so it exercises its own auth path and refreshes the
    /// credential if it is due. Output is discarded: the credential fingerprint
    /// is the result, and the CLI's stdout may carry account details this app
    /// has no business retaining.
    private static func runStatusTouch(timeout: TimeInterval = 15) async throws {
        guard let executable = try? ClaudeExecutableLocator().locate() else {
            throw ClaudeDelegatedRefreshError.cliUnavailable
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["auth", "status", "--json"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                throw ClaudeDelegatedRefreshError.timedOut
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

enum ClaudeDelegatedRefreshError: Error {
    case cliUnavailable
    case timedOut
}
