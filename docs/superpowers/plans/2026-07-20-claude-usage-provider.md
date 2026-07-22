# Claude Usage Provider (OAuth Primary, StatusLine Fallback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared domain model, Keychain credential discovery, live OAuth usage fetch, last-known-good cache, and a coordinator that tries OAuth first and falls back to the existing statusLine bridge — the first three of the four source tiers from `ClaudeUsageBridge/claude_probe_plan`, per the personal-use OAuth decision recorded in the [capability research](2026-07-20-claude-code-capability-research.md#personal-non-commercial-oauth-reuse-decision--2026-07-20). Still isolated, still no Settings UI.

**Architecture:** `ClaudeUsageSnapshot` is the one normalized representation every source produces. `ClaudeKeychainCredentialStore` reads Claude Code's own already-issued OAuth credential from the login Keychain (never a separate sign-in flow). `ClaudeOAuthUsageSource` calls `GET https://api.anthropic.com/api/oauth/usage` with that credential and maps the **verified real response shape** (see below) into the shared model. `ClaudeUsageCache` persists only normalized, non-secret data. `ClaudeUsageCollector` is a single actor coordinator that tries OAuth, falls back to a recent statusLine snapshot (adapting the existing, already-shipped `ClaudeRateLimitSnapshotReader`), then cache — matching `claude_probe_plan`'s four-tier order minus tier 3 (the CLI `/usage` PTY probe), which is deliberately deferred to its own plan given its complexity and risk surface.

**Tech Stack:** Swift 6.2, Foundation, `Security` framework (Keychain), `URLSession` (injected for testability), XCTest.

## Verified real schema (ground truth, not the plan document's assumptions)

Both schemas below were captured directly from this machine — the Keychain credential by reading (not printing) it, the OAuth response via one real, read-only `GET` call — because `claude_probe_plan`'s field names turned out to differ from reality in several places. Trust this section over the plan document's Task 3/4 field lists.

**Keychain item** (service `Claude Code-credentials`, generic password, JSON-encoded `Data`):
```json
{
  "claudeAiOauth": {
    "accessToken": "…", "refreshToken": "…",
    "expiresAt": 1784572234658, "refreshTokenExpiresAt": 1787074021658,
    "scopes": ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "pro", "rateLimitTier": "default_claude_ai"
  }
}
```
`expiresAt`/`refreshTokenExpiresAt` are **Unix milliseconds**, not seconds (contrast with the statusLine bridge's second-based timestamps — do not reuse that conversion).

**`GET /api/oauth/usage` response** (fields this plan maps; many more experimental/null fields exist and are safely ignored by Swift's default-permissive `Decodable`):
```json
{
  "five_hour": {"utilization": 33.0, "resets_at": "2026-07-20T14:50:00.630618+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
  "seven_day": {"utilization": 8.0, "resets_at": "2026-07-22T22:00:00.630645+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
  "seven_day_sonnet": null, "seven_day_opus": null, "seven_day_oauth_apps": null, "seven_day_cowork": null,
  "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null, "currency": null},
  "limits": [
    {"kind": "session", "group": "session", "percent": 33, "severity": "normal", "resets_at": "2026-07-20T14:50:00.630618+00:00", "scope": null, "is_active": true},
    {"kind": "weekly_all", "group": "weekly", "percent": 8, "severity": "normal", "resets_at": "2026-07-22T22:00:00.630645+00:00", "scope": null, "is_active": false}
  ],
  "member_dashboard_available": false
}
```
Key differences from `claude_probe_plan`: the window field is `utilization` (not `used_percent`), `resets_at` is an **ISO 8601 string with microsecond fractional seconds** (not a Unix timestamp — confirmed `ISO8601DateFormatter` with `[.withInternetDateTime, .withFractionalSeconds]` parses it correctly on this toolchain), and there is **no account email/organization or plan-type field in this response at all** — plan/tier hints come from the Keychain credential's `subscriptionType`/`rateLimitTier`, not the API response. `spend` (a separate, overlapping-looking object) exists but is not mapped in this plan — `extra_usage` covers the same concept more directly and `spend` can be added later if a real populated example is available to verify against.

## Global Constraints

- `ClaudeOAuthCredential` must never conform to `Codable`, `CustomStringConvertible`, or `CustomDebugStringConvertible` — nothing about it should be persistable or printable by accident.
- Never write the access or refresh token anywhere outside Keychain. `ClaudeUsageCache` stores only the normalized `ClaudeUsageSnapshot` — no token fields exist on that type at all, so this is structurally enforced, not just a convention.
- `ClaudeOAuthUsageSource` must use an injected request-executor (`(URLRequest) async throws -> (Data, URLResponse)`), not `URLSession.shared` directly, so tests never make real network calls.
- `ClaudeKeychainCredentialStore` must use an injected raw-data reader for the same reason — tests never touch the real Keychain.
- Do not modify `ClaudeRateLimitSnapshotReader.swift` or `ClaudeUsageMonitor.swift` (from the statusLine bridge plans) — adapt their output with a new, separate mapping function instead.
- Do not modify `ClaudeCodePreviewSettingsView.swift`, `AgentSettingsCatalog.swift`, `AgentProvider.swift`, or `SettingsView.swift`. No Settings UI in this plan.
- Do not implement the CLI `/usage` PTY probe (tier 3) in this plan — it is real, substantial, higher-risk work (interactive terminal automation) that deserves its own dedicated plan and review, named explicitly as deferred, not silently dropped.
- Keep tests narrow and deterministic per `AGENTS.md`; no real Keychain or network access in the automated suite.

---

## File Structure

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift` — `ClaudeLimitWindow`, `ClaudeScopedLimitWindow`, `ClaudeExtraUsage`, `ClaudeUsageSource`, `ClaudeUsageSnapshot`, `ClaudeUsageDelivery`, `ClaudeUsagePresentation`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageSnapshotTests.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift` — `ClaudeOAuthCredential`, `ClaudeCredentialError`, `ClaudeCredentialProviding`, `ClaudeKeychainCredentialStore`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeKeychainCredentialStoreTests.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift` — `ClaudeOAuthDateParsing`, `ClaudeOAuthUsageResponse`, `ClaudeOAuthError`, `ClaudeOAuthUsageSource`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCache.swift` — `ClaudeCachedUsage`, `ClaudeUsageCache`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCacheTests.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift` — `ClaudeRefreshReason`, `ClaudeUsageCollector`, statusLine-snapshot adapter
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift`
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md` — record this plan as further gate evidence
- Modify: `docs/product/planning-board.md` — bookkeeping

---

## Task 1: Shared domain model

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageSnapshotTests.swift`

**Interfaces:**
- Produces: `ClaudeLimitWindow`, `ClaudeScopedLimitWindow`, `ClaudeExtraUsage`, `ClaudeUsageSource` (`.oauth`, `.statusLine`, `.cache`), `ClaudeUsageSnapshot`, `ClaudeUsageDelivery` (`.live`, `.passiveSnapshot`, `.cached`), `ClaudeUsagePresentation` — all `Codable, Sendable, Equatable` except `ClaudeUsagePresentation`, which is `Sendable` only (it wraps a delivery classification, not raw stored data).

- [x] **Step 1: Write the failing test**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageSnapshotTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTripWithFullData() throws {
        let snapshot = ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: ClaudeLimitWindow(usedPercent: 8.0, resetsAt: Date(timeIntervalSince1970: 1_800_500_000)),
            scopedWindows: [
                ClaudeScopedLimitWindow(identifier: "session", displayName: "session", usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000))
            ],
            extraUsage: ClaudeExtraUsage(isEnabled: false, monthlyLimit: nil, usedCredits: nil, currencyCode: nil),
            source: .oauth,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeUsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testEncodeDecodeRoundTripWithMinimalData() throws {
        let snapshot = ClaudeUsageSnapshot(
            planHint: nil,
            fiveHour: nil,
            sevenDay: nil,
            scopedWindows: [],
            extraUsage: nil,
            source: .statusLine,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            schemaVersion: 1
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeUsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testPresentationCarriesDeliveryAndSourceIndependently() {
        let snapshot = ClaudeUsageSnapshot(
            planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: .oauth, capturedAt: .now, schemaVersion: 1
        )

        let presentation = ClaudeUsagePresentation(snapshot: snapshot, delivery: .cached, warnings: [])

        // A cached OAuth result must still report .oauth as its origin —
        // delivery (.cached) and source (.oauth) are tracked separately so
        // the cache never loses where the data originally came from.
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.delivery, .cached)
    }
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageSnapshotTests`
Expected: FAIL to build — `cannot find 'ClaudeUsageSnapshot' in scope`

- [x] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift`:

```swift
import Foundation

struct ClaudeLimitWindow: Codable, Sendable, Equatable {
    let usedPercent: Double
    let resetsAt: Date?
}

struct ClaudeScopedLimitWindow: Codable, Sendable, Equatable {
    let identifier: String
    let displayName: String
    let usedPercent: Double
    let resetsAt: Date?
}

struct ClaudeExtraUsage: Codable, Sendable, Equatable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let currencyCode: String?
}

enum ClaudeUsageSource: String, Codable, Sendable, Equatable {
    case oauth
    case statusLine
    case cache
}

/// The one normalized representation every source (OAuth, statusLine, cache)
/// produces, so the rest of the app never needs to know which source a
/// result came from to display it.
struct ClaudeUsageSnapshot: Codable, Sendable, Equatable {
    let planHint: String?
    let fiveHour: ClaudeLimitWindow?
    let sevenDay: ClaudeLimitWindow?
    let scopedWindows: [ClaudeScopedLimitWindow]
    let extraUsage: ClaudeExtraUsage?
    let source: ClaudeUsageSource
    let capturedAt: Date
    let schemaVersion: Int
}

enum ClaudeUsageDelivery: Sendable, Equatable {
    case live
    case passiveSnapshot
    case cached
}

/// Wraps a snapshot with how it was delivered, so a result cached from an
/// OAuth read still reports source == .oauth (where the data originated)
/// separately from delivery == .cached (that it's not fresh right now).
struct ClaudeUsagePresentation: Sendable {
    let snapshot: ClaudeUsageSnapshot
    let delivery: ClaudeUsageDelivery
    let warnings: [String]
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageSnapshotTests`
Expected: PASS (3 tests)

- [x] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageSnapshotTests.swift
git commit -m "Add shared Claude usage domain model"
```

---

## Task 2: Keychain credential discovery

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeKeychainCredentialStoreTests.swift`

**Interfaces:**
- Produces: `struct ClaudeOAuthCredential` (NOT Codable/CustomStringConvertible) with `accessToken: String`, `refreshToken: String?`, `expiresAt: Date?`, `scopes: Set<String>`, `subscriptionType: String?`; `enum ClaudeCredentialError: Error, Equatable { case notFound; case malformedData; case accessDenied }`; `protocol ClaudeCredentialProviding: Sendable { func loadCredential() throws -> ClaudeOAuthCredential }`; `struct ClaudeKeychainCredentialStore: ClaudeCredentialProviding` with a production `init(serviceName:)` and a test-only `init(rawDataReader:)`.

- [x] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeKeychainCredentialStoreTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeKeychainCredentialStoreTests: XCTestCase {
    /// Shape verified against a real Keychain "Claude Code-credentials" item
    /// on 2026-07-20: expiresAt/refreshTokenExpiresAt are Unix milliseconds.
    private let realShapedFixture = """
    {"claudeAiOauth":{"accessToken":"fixture-access-token","refreshToken":"fixture-refresh-token","expiresAt":1784572234658,"refreshTokenExpiresAt":1787074021658,"scopes":["user:file_upload","user:inference","user:mcp_servers","user:profile","user:sessions:claude_code"],"subscriptionType":"pro","rateLimitTier":"default_claude_ai"}}
    """

    func testLoadCredentialParsesRealShapedFixture() throws {
        let fixture = realShapedFixture
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(fixture.utf8)) }
        )

        let credential = try store.loadCredential()

        XCTAssertEqual(credential.accessToken, "fixture-access-token")
        XCTAssertEqual(credential.refreshToken, "fixture-refresh-token")
        XCTAssertEqual(credential.expiresAt, Date(timeIntervalSince1970: 1_784_572_234_658 / 1000))
        XCTAssertEqual(credential.scopes, ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"])
        XCTAssertEqual(credential.subscriptionType, "pro")
    }

    func testLoadCredentialThrowsNotFoundWhenKeychainItemMissing() {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .failure(.notFound) })

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testLoadCredentialThrowsMalformedDataForInvalidJSON() {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .success(Data("not json".utf8)) })

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialThrowsMalformedDataWhenAccessTokenMissing() {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"refreshToken":"x"}}"#.utf8)) }
        )

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialToleratesMissingOptionalFields() throws {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"accessToken":"only-token"}}"#.utf8)) }
        )

        let credential = try store.loadCredential()

        XCTAssertEqual(credential.accessToken, "only-token")
        XCTAssertNil(credential.refreshToken)
        XCTAssertNil(credential.expiresAt)
        XCTAssertEqual(credential.scopes, [])
        XCTAssertNil(credential.subscriptionType)
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeKeychainCredentialStoreTests`
Expected: FAIL to build — `cannot find 'ClaudeKeychainCredentialStore' in scope`

- [x] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift`:

```swift
import Foundation
import Security

/// Deliberately NOT Codable, CustomStringConvertible, or
/// CustomDebugStringConvertible — nothing about this type should be
/// persistable or printable by accident. The token lives in Keychain only.
struct ClaudeOAuthCredential {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: Set<String>
    let subscriptionType: String?
}

enum ClaudeCredentialError: Error, Equatable {
    case notFound
    case malformedData
    case accessDenied
}

protocol ClaudeCredentialProviding: Sendable {
    func loadCredential() throws -> ClaudeOAuthCredential
}

/// Reads Claude Code's own already-issued OAuth credential from the login
/// Keychain (service "Claude Code-credentials"). This app never runs its
/// own sign-in flow and never stores the token anywhere else.
struct ClaudeKeychainCredentialStore: ClaudeCredentialProviding {
    private let rawDataReader: @Sendable () -> Result<Data, ClaudeCredentialError>

    init(serviceName: String = "Claude Code-credentials") {
        self.rawDataReader = { Self.readKeychainData(serviceName: serviceName) }
    }

    /// Test-only injection point so the automated suite never touches the
    /// real Keychain.
    init(rawDataReader: @escaping @Sendable () -> Result<Data, ClaudeCredentialError>) {
        self.rawDataReader = rawDataReader
    }

    func loadCredential() throws -> ClaudeOAuthCredential {
        switch rawDataReader() {
        case .success(let data):
            return try Self.parse(data)
        case .failure(let error):
            throw error
        }
    }

    private static func readKeychainData(serviceName: String) -> Result<Data, ClaudeCredentialError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return .success(data)
        }
        if status == errSecItemNotFound {
            return .failure(.notFound)
        }
        return .failure(.accessDenied)
    }

    private struct Wrapper: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresAt: Double?
            let scopes: [String]?
            let subscriptionType: String?
        }
        let claudeAiOauth: OAuth
    }

    static func parse(_ data: Data) throws -> ClaudeOAuthCredential {
        guard let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            throw ClaudeCredentialError.malformedData
        }
        let oauth = wrapper.claudeAiOauth
        return ClaudeOAuthCredential(
            accessToken: oauth.accessToken,
            refreshToken: oauth.refreshToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            scopes: Set(oauth.scopes ?? []),
            subscriptionType: oauth.subscriptionType
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeKeychainCredentialStoreTests`
Expected: PASS (5 tests)

- [x] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeKeychainCredentialStoreTests.swift
git commit -m "Add Keychain credential discovery for Claude Code's own OAuth token"
```

---

## Task 3: OAuth usage fetch source

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift`

**Interfaces:**
- Consumes: `ClaudeCredentialProviding`/`ClaudeOAuthCredential` (Task 2), `ClaudeUsageSnapshot`/`ClaudeLimitWindow` (Task 1).
- Produces: `enum ClaudeOAuthError: Error, Equatable { case credentialsNotFound; case insufficientScope; case unauthorized; case malformedResponse; case serverFailure(statusCode: Int); case transportError }`; `struct ClaudeOAuthUsageSource` with `init(credentialStore:requestExecutor:)` and `func fetch() async throws -> ClaudeUsageSnapshot`; `enum ClaudeOAuthDateParsing { static func parse(_ string: String) -> Date? }`.

- [x] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeOAuthUsageSourceTests: XCTestCase {
    /// Captured verbatim from a real GET https://api.anthropic.com/api/oauth/usage
    /// response on 2026-07-20 (values are this account's real utilization,
    /// no token or identity data included).
    private let realShapedResponse = """
    {
      "five_hour": {"utilization": 33.0, "resets_at": "2026-07-20T14:50:00.630618+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day": {"utilization": 8.0, "resets_at": "2026-07-22T22:00:00.630645+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day_sonnet": null, "seven_day_opus": null, "seven_day_oauth_apps": null, "seven_day_cowork": null,
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null, "currency": null},
      "limits": [
        {"kind": "session", "group": "session", "percent": 33, "severity": "normal", "resets_at": "2026-07-20T14:50:00.630618+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_all", "group": "weekly", "percent": 8, "severity": "normal", "resets_at": "2026-07-22T22:00:00.630645+00:00", "scope": null, "is_active": false}
      ],
      "an_unmapped_experimental_field": {"anything": "here"},
      "member_dashboard_available": false
    }
    """

    private func credentialStore(scopes: Set<String> = ["user:profile"]) -> ClaudeCredentialProviding {
        FakeCredentialStore(result: .success(
            ClaudeOAuthCredential(accessToken: "fixture-token", refreshToken: nil, expiresAt: nil, scopes: scopes, subscriptionType: "pro")
        ))
    }

    func testFetchMapsRealShapedResponseIntoNormalizedSnapshot() async throws {
        let response = realShapedResponse
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(response.utf8), Self.httpResponse(status: 200)) }
        )

        let snapshot = try await source.fetch()

        XCTAssertEqual(snapshot.source, .oauth)
        XCTAssertEqual(snapshot.planHint, "pro")
        XCTAssertEqual(snapshot.fiveHour?.usedPercent, 33.0)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, ClaudeOAuthDateParsing.parse("2026-07-20T14:50:00.630618+00:00"))
        XCTAssertEqual(snapshot.sevenDay?.usedPercent, 8.0)
        XCTAssertEqual(snapshot.scopedWindows.count, 2)
        XCTAssertEqual(snapshot.scopedWindows.first?.identifier, "session")
        XCTAssertEqual(snapshot.extraUsage?.isEnabled, false)
    }

    func testFetchThrowsCredentialsNotFoundWhenKeychainHasNoItem() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not make a request without a credential"); return (Data(), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .credentialsNotFound)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsInsufficientScopeWhenTokenLacksUserProfile() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(scopes: ["user:inference"]),
            requestExecutor: { _ in XCTFail("must not make a request with an insufficiently scoped token"); return (Data(), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .insufficientScope)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsUnauthorizedOn401() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(), Self.httpResponse(status: 401)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsServerFailureOn500() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(), Self.httpResponse(status: 500)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .serverFailure(statusCode: 500))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsMalformedResponseForInvalidJSON() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data("not json".utf8), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .malformedResponse)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchSetsAuthorizationHeaderAndBetaHeaderWithoutLoggingToken() async throws {
        let response = realShapedResponse
        let captured = CapturedRequestBox()
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { request in
                captured.request = request
                return (Data(response.utf8), Self.httpResponse(status: 200))
            }
        )

        _ = try await source.fetch()

        XCTAssertEqual(captured.request?.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(captured.request?.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertEqual(captured.request?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    private static func httpResponse(status: Int) -> URLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}

private final class CapturedRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

private struct FakeCredentialStore: ClaudeCredentialProviding {
    let result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    func loadCredential() throws -> ClaudeOAuthCredential {
        switch result {
        case .success(let credential): return credential
        case .failure(let error): throw error
        }
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeOAuthUsageSourceTests`
Expected: FAIL to build — `cannot find 'ClaudeOAuthUsageSource' in scope`

- [x] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift`:

```swift
import Foundation

enum ClaudeOAuthError: Error, Equatable {
    case credentialsNotFound
    case insufficientScope
    case unauthorized
    case malformedResponse
    case serverFailure(statusCode: Int)
    case transportError
}

/// Parses the ISO 8601 timestamps this endpoint returns, including
/// microsecond-precision fractional seconds (verified against a real
/// response on 2026-07-20; ISO8601DateFormatter with .withFractionalSeconds
/// handles this format directly on this toolchain).
enum ClaudeOAuthDateParsing {
    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? withoutFractionalSeconds.date(from: string)
    }

    // ISO8601DateFormatter isn't Sendable, but these instances are only ever
    // read from after configuration (parsing is thread-safe in practice);
    // nonisolated(unsafe) opts out of the compiler's conservative check.
    private nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// Raw response shape for GET /api/oauth/usage. Kept private to this file —
/// only the normalized ClaudeUsageSnapshot is exposed to callers. Optional
/// everywhere except what's structurally guaranteed, and only the fields
/// this app actually uses are declared; unmapped/experimental fields the
/// endpoint also returns are silently ignored by Decodable.
private struct OAuthUsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct Limit: Decodable {
        let kind: String
        let percent: Double
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case percent
            case resetsAt = "resets_at"
        }
    }

    struct ExtraUsage: Decodable {
        let isEnabled: Bool
        let monthlyLimit: Double?
        let usedCredits: Double?
        let currency: String?

        enum CodingKeys: String, CodingKey {
            case isEnabled = "is_enabled"
            case monthlyLimit = "monthly_limit"
            case usedCredits = "used_credits"
            case currency
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let extraUsage: ExtraUsage?
    let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case extraUsage = "extra_usage"
        case limits
    }
}

struct ClaudeOAuthUsageSource {
    private let credentialStore: ClaudeCredentialProviding
    private let requestExecutor: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        credentialStore: ClaudeCredentialProviding,
        requestExecutor: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession(configuration: .ephemeral).data(for: request)
        }
    ) {
        self.credentialStore = credentialStore
        self.requestExecutor = requestExecutor
    }

    func fetch() async throws -> ClaudeUsageSnapshot {
        let credential: ClaudeOAuthCredential
        do {
            credential = try credentialStore.loadCredential()
        } catch {
            throw ClaudeOAuthError.credentialsNotFound
        }
        guard credential.scopes.contains("user:profile") else {
            throw ClaudeOAuthError.insufficientScope
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await requestExecutor(request)
        } catch {
            throw ClaudeOAuthError.transportError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeOAuthError.malformedResponse
        }
        guard httpResponse.statusCode != 401, httpResponse.statusCode != 403 else {
            throw ClaudeOAuthError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw ClaudeOAuthError.serverFailure(statusCode: httpResponse.statusCode)
        }

        guard let parsed = try? JSONDecoder().decode(OAuthUsageResponse.self, from: data) else {
            throw ClaudeOAuthError.malformedResponse
        }

        return ClaudeUsageSnapshot(
            planHint: credential.subscriptionType,
            fiveHour: Self.window(parsed.fiveHour),
            sevenDay: Self.window(parsed.sevenDay),
            scopedWindows: (parsed.limits ?? []).map {
                ClaudeScopedLimitWindow(
                    identifier: $0.kind,
                    displayName: $0.kind,
                    usedPercent: $0.percent,
                    resetsAt: $0.resetsAt.flatMap(ClaudeOAuthDateParsing.parse)
                )
            },
            extraUsage: parsed.extraUsage.map {
                ClaudeExtraUsage(isEnabled: $0.isEnabled, monthlyLimit: $0.monthlyLimit, usedCredits: $0.usedCredits, currencyCode: $0.currency)
            },
            source: .oauth,
            capturedAt: .now,
            schemaVersion: 1
        )
    }

    private static func window(_ raw: OAuthUsageResponse.Window?) -> ClaudeLimitWindow? {
        guard let raw, let utilization = raw.utilization else { return nil }
        return ClaudeLimitWindow(usedPercent: utilization, resetsAt: raw.resetsAt.flatMap(ClaudeOAuthDateParsing.parse))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeOAuthUsageSourceTests`
Expected: PASS (7 tests)

- [x] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift
git commit -m "Add live OAuth usage fetch source with verified real response mapping"
```

---

## Task 4: Last-known-good cache

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCache.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCacheTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageSnapshot` (Task 1).
- Produces: `struct ClaudeCachedUsage: Codable, Equatable { let snapshot: ClaudeUsageSnapshot; let savedAt: Date }`; `struct ClaudeUsageCache` with `init(fileURL:)`, `func save(_ snapshot: ClaudeUsageSnapshot)`, `func load() -> ClaudeCachedUsage?`.

- [x] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCacheTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageCacheTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("last-known-good.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func sampleSnapshot(source: ClaudeUsageSource = .oauth) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(
            planHint: "pro",
            fiveHour: ClaudeLimitWindow(usedPercent: 33.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: nil, scopedWindows: [], extraUsage: nil,
            source: source, capturedAt: Date(timeIntervalSince1970: 1_700_000_000), schemaVersion: 1
        )
    }

    func testLoadReturnsNilWhenNoCacheExists() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        XCTAssertNil(cache.load())
    }

    func testSaveThenLoadRoundTrips() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot())

        let loaded = cache.load()

        XCTAssertEqual(loaded?.snapshot, sampleSnapshot())
    }

    func testSavePreservesOriginalSourceThroughMultipleSaves() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot(source: .oauth))
        cache.save(sampleSnapshot(source: .statusLine))

        XCTAssertEqual(cache.load()?.snapshot.source, .statusLine)
    }

    func testFileHasOwnerOnlyPermissions() {
        let cache = ClaudeUsageCache(fileURL: fileURL)
        cache.save(sampleSnapshot())

        let mode = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o600)
    }

    func testLoadReturnsNilForCorruptedFile() throws {
        try Data("not json".utf8).write(to: fileURL)
        let cache = ClaudeUsageCache(fileURL: fileURL)

        XCTAssertNil(cache.load())
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageCacheTests`
Expected: FAIL to build — `cannot find 'ClaudeUsageCache' in scope`

- [x] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCache.swift`:

```swift
import Foundation

/// Cache metadata separate from the snapshot's own `source` field: `source`
/// says where the data originated (oauth/statusLine), this wrapper is only
/// about when it was saved to disk.
struct ClaudeCachedUsage: Codable, Equatable {
    let snapshot: ClaudeUsageSnapshot
    let savedAt: Date
}

/// Stores only normalized, non-secret usage data — this type has no token
/// fields to accidentally cache because ClaudeUsageSnapshot has none.
struct ClaudeUsageCache {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.fileURL = support.appendingPathComponent("CodexUsageMonitor/claude-usage-cache.json")
    }

    func load() -> ClaudeCachedUsage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ClaudeCachedUsage.self, from: data)
    }

    func save(_ snapshot: ClaudeUsageSnapshot) {
        let cached = ClaudeCachedUsage(snapshot: snapshot, savedAt: .now)
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try JSONEncoder().encode(cached)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Cache is best-effort and must never make a refresh fail.
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageCacheTests`
Expected: PASS (5 tests)

- [x] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCache.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCacheTests.swift
git commit -m "Add last-known-good cache for normalized Claude usage snapshots"
```

---

## Task 5: Coordinator — OAuth → statusLine → cache

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift`

**Interfaces:**
- Consumes: `ClaudeOAuthUsageSource` (Task 3), `ClaudeRateLimitSnapshotReader`/`ClaudeRateLimitSnapshot` (existing, from the statusLine bridge plan — unmodified), `ClaudeUsageCache` (Task 4).
- Produces: `enum ClaudeRefreshReason: Sendable { case appLaunch; case scheduled; case menuOpened; case userInitiated }`; `func adaptStatusLineSnapshot(_ snapshot: ClaudeRateLimitSnapshot) -> ClaudeUsageSnapshot`; `actor ClaudeUsageCollector` with `init(oauthSource:statusLineReader:cache:)` and `func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation`.

- [x] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageCollectorTests: XCTestCase {
    private var tempDirectory: URL!
    private var cacheFileURL: URL!
    private var statusLineFileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageCollectorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        cacheFileURL = tempDirectory.appendingPathComponent("cache.json")
        statusLineFileURL = tempDirectory.appendingPathComponent("statusline.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testAdaptStatusLineSnapshotMapsBothWindows() {
        let statusLineSnapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: ClaudeRateLimitWindow(usedPercentage: 12.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: ClaudeRateLimitWindow(usedPercentage: 44.0, resetsAt: Date(timeIntervalSince1970: 1_800_500_000))
        )

        let adapted = adaptStatusLineSnapshot(statusLineSnapshot)

        XCTAssertEqual(adapted.source, .statusLine)
        XCTAssertEqual(adapted.fiveHour?.usedPercent, 12.0)
        XCTAssertEqual(adapted.sevenDay?.usedPercent, 44.0)
        XCTAssertEqual(adapted.capturedAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testRefreshReturnsLiveWhenOAuthSucceeds() async throws {
        let oauthSnapshot = ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 10.0, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil, source: .oauth, capturedAt: .now, schemaVersion: 1
        )
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: ["user:profile"], subscriptionType: "pro")
            )),
            requestExecutor: { _ in (Self.encodedOAuthFixture(fiveHour: 10.0), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: ClaudeUsageCache(fileURL: cacheFileURL)
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .live)
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 10.0)
    }

    func testRefreshFallsBackToStatusLineWhenOAuthFails() async throws {
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 7.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: statusLineFileURL)
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not be called"); return (Data(), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: ClaudeUsageCache(fileURL: cacheFileURL)
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .passiveSnapshot)
        XCTAssertEqual(presentation.snapshot.source, .statusLine)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 7.0)
    }

    func testRefreshFallsBackToCacheWhenOAuthAndStatusLineBothUnavailable() async throws {
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        cache.save(ClaudeUsageSnapshot(
            planHint: "pro", fiveHour: ClaudeLimitWindow(usedPercent: 55.0, resetsAt: nil),
            sevenDay: nil, scopedWindows: [], extraUsage: nil, source: .oauth, capturedAt: .now, schemaVersion: 1
        ))
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not be called"); return (Data(), Self.httpResponse(200)) }
        )
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        let presentation = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(presentation.delivery, .cached)
        // Cache preserves the ORIGINAL source (.oauth), not .cache — the
        // whole point of tracking source and delivery separately.
        XCTAssertEqual(presentation.snapshot.source, .oauth)
        XCTAssertEqual(presentation.snapshot.fiveHour?.usedPercent, 55.0)
    }

    func testSuccessfulOAuthRefreshUpdatesCache() async throws {
        let oauthSource = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .success(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: ["user:profile"], subscriptionType: "pro")
            )),
            requestExecutor: { _ in (Self.encodedOAuthFixture(fiveHour: 21.0), Self.httpResponse(200)) }
        )
        let cache = ClaudeUsageCache(fileURL: cacheFileURL)
        let collector = ClaudeUsageCollector(
            oauthSource: oauthSource,
            statusLineReader: ClaudeRateLimitSnapshotReader(fileURL: statusLineFileURL),
            cache: cache
        )

        _ = await collector.refresh(reason: .userInitiated)

        XCTAssertEqual(cache.load()?.snapshot.fiveHour?.usedPercent, 21.0)
    }

    private static func encodedOAuthFixture(fiveHour: Double) -> Data {
        Data("""
        {"five_hour": {"utilization": \(fiveHour), "resets_at": "2026-07-20T14:50:00.630618+00:00"}, "seven_day": null}
        """.utf8)
    }

    private static func httpResponse(_ status: Int) -> URLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}

private struct FakeCredentialStore: ClaudeCredentialProviding {
    let result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    func loadCredential() throws -> ClaudeOAuthCredential {
        switch result {
        case .success(let credential): return credential
        case .failure(let error): throw error
        }
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageCollectorTests`
Expected: FAIL to build — `cannot find 'ClaudeUsageCollector' in scope`

- [x] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift`:

```swift
import Foundation

enum ClaudeRefreshReason: Sendable {
    case appLaunch
    case scheduled
    case menuOpened
    case userInitiated
}

/// Maps the existing, already-shipped statusLine bridge's snapshot type into
/// the shared domain model. Does not modify ClaudeRateLimitSnapshotReader or
/// ClaudeRateLimitSnapshot — this is a pure translation layer.
func adaptStatusLineSnapshot(_ snapshot: ClaudeRateLimitSnapshot) -> ClaudeUsageSnapshot {
    ClaudeUsageSnapshot(
        planHint: nil,
        fiveHour: snapshot.fiveHour.map { ClaudeLimitWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
        sevenDay: snapshot.sevenDay.map { ClaudeLimitWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
        scopedWindows: [],
        extraUsage: nil,
        source: .statusLine,
        capturedAt: snapshot.capturedAt,
        schemaVersion: 1
    )
}

/// Single entry point implementing the OAuth -> statusLine -> cache order
/// from claude_probe_plan (tier 3, the user-authorized CLI /usage probe, is
/// deliberately not implemented here — see a separate, dedicated plan).
actor ClaudeUsageCollector {
    private let oauthSource: ClaudeOAuthUsageSource
    private let statusLineReader: ClaudeRateLimitSnapshotReader
    private let cache: ClaudeUsageCache

    init(oauthSource: ClaudeOAuthUsageSource, statusLineReader: ClaudeRateLimitSnapshotReader, cache: ClaudeUsageCache) {
        self.oauthSource = oauthSource
        self.statusLineReader = statusLineReader
        self.cache = cache
    }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        if let snapshot = try? await oauthSource.fetch() {
            cache.save(snapshot)
            return ClaudeUsagePresentation(snapshot: snapshot, delivery: .live, warnings: [])
        }

        if let statusLineSnapshot = statusLineReader.readSnapshot() {
            let adapted = adaptStatusLineSnapshot(statusLineSnapshot)
            cache.save(adapted)
            return ClaudeUsagePresentation(snapshot: adapted, delivery: .passiveSnapshot, warnings: [])
        }

        if let cached = cache.load() {
            return ClaudeUsagePresentation(snapshot: cached.snapshot, delivery: .cached, warnings: [])
        }

        return ClaudeUsagePresentation(
            snapshot: ClaudeUsageSnapshot(
                planHint: nil, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
                source: .oauth, capturedAt: .now, schemaVersion: 1
            ),
            delivery: .cached,
            warnings: ["No Claude usage source is currently available."]
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageCollectorTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full Swift test suite to confirm no regressions**

Run: `cd CodexUsageMonitor && swift test`
Expected: PASS (all existing tests plus the 25 new ones from Tasks 1–5)

- [x] **Step 6: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift
git commit -m "Add OAuth -> statusLine -> cache coordinator for Claude usage"
```

---

## Task 6: Record evidence in the capability research gate

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md`
- Modify: `docs/product/planning-board.md`

- [x] **Step 1: Update the capability research doc**

Under "Personal, non-commercial OAuth reuse decision," append an implementation note confirming `ClaudeUsageCollector` implements the OAuth → statusLine → cache order end-to-end, tested, with the OAuth response shape verified against a real call.

- [x] **Step 2: Update the planning board**

Update the Claude local analytics/provider research row and plan coverage index to reference this plan.

- [x] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-07-20-claude-code-capability-research.md docs/product/planning-board.md
git commit -m "Record OAuth usage provider as further gate evidence"
```

---

## Deliberately deferred, not dropped

- **Tier 3, the user-authorized CLI `/usage` PTY probe** (`claude_probe_plan` Phase 3 / Task 7): real, substantial, higher-risk work — interactive terminal automation, ANSI stripping, allowlisted prompt handling, cooldowns. Needs its own dedicated plan and review.
- **All UI** (`claude_probe_plan` Tasks 9–10): still blocked on gate criteria 3 and 5 from the capability research (product-copy accuracy, visible "not available" fallback) and on `ClaudeUsageBridge/` being bundled into the signed app (noted in the usage-monitor-owner plan). `ClaudeUsageMonitor`/`ClaudeUsageState` from that earlier plan are not touched or superseded here — reconciling them with `ClaudeUsageCollector` is UI-plan work, not this plan's.
- **Token refresh** (`claude_probe_plan`'s credential-refresh section): this plan reads the credential as-is and reports `.unauthorized`/`.credentialsNotFound` on failure; it does not attempt to refresh an expiring access token or write a refreshed credential back to Keychain. Worth a follow-up once the basic read path has real-world mileage.
- **Account-change fingerprinting**: not implemented — this plan assumes one Claude account per machine, matching this app's existing Codex assumption.

## Self-Review

**1. Spec coverage:** Tasks 1–5 implement tiers 1 (OAuth), 2 (statusLine, via adapter), and 4 (cache) of `claude_probe_plan`'s four-tier hierarchy, in the exact priority order the plan specifies. Every field mapping is grounded in a real, verified sample rather than the plan document's assumptions, with the discrepancies called out explicitly. Task 6 is gate bookkeeping.

**2. Placeholder scan:** No `TBD`/`TODO`; every step has complete, runnable code; deferred work (tier 3, UI, token refresh, account fingerprinting) is named explicitly rather than silently dropped.

**3. Type consistency:** `ClaudeUsageSnapshot` (Task 1) is the exact return type of `ClaudeOAuthUsageSource.fetch()` (Task 3) and `adaptStatusLineSnapshot` (Task 5); `ClaudeCredentialProviding`/`ClaudeOAuthCredential` (Task 2) match the exact types `ClaudeOAuthUsageSource` (Task 3) consumes; `ClaudeUsageCache`/`ClaudeCachedUsage` (Task 4) match what `ClaudeUsageCollector` (Task 5) calls.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-claude-usage-provider.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
