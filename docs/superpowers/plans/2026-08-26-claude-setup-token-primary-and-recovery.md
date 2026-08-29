# Claude Setup-Token Primary and Explicit Recovery Implementation Plan

> **Superseded 2026-08-29:** A direct Claude Code 2.1.247 `setup-token` run
> proved callback/token completion; installed CLI semantics and the endpoint's
> rejection establish that the inference token lacks the `user:profile` scope
> required by `/api/oauth/usage`. Do not continue this implementation.
> Follow [Claude Keychain, Passive Usage, and Single-Binary Bridge](./2026-08-29-claude-keychain-statusline-single-binary.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use `swift-security-expert` for every credential or Keychain change, `swift-concurrency-pro` for actor/cancellation work, `swiftui-pro` and `writing-for-interfaces` for the Settings/menu surfaces, `systematic-debugging` for the live capability gate, and `verification-before-completion` before any completion claim. Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make an App-Owned Claude Credential created by `claude setup-token` the normal authoritative Claude credential after one connection, retain Borrowed Claude Code Credentials as an explicit compatibility choice, and retain `claude -p /usage` as an explicit Forced Claude Usage Read.

**Architecture:** Preserve the app's existing MVVM composition: `QuotaViewModel` owns user intents and presentation state, `ClaudeConnectionController` owns the connection transition, `ClaudeUsageMonitor` owns the read cycle, and `ClaudeUsageCollector` owns source ordering. Move all Keychain mutation and reads into actors, make the selected credential method a durable non-secret preference, and inject one mutable credential router into both connection and monitoring paths. A fresh Passive Claude Usage Snapshot still short-circuits all credential access.

**Tech Stack:** Swift 6.2, SwiftUI and Combine on macOS 14+, Foundation `Process`, Darwin PTY APIs, Security framework data-protection Keychain, XCTest, Swift Package Manager, and the repository's signed-app build script.

## Implementation Status — 2026-08-26

Implemented on `feat/claude-setup-token-primary`: actor-isolated app-owned and borrowed Keychain boundaries, stable service/account data-protection storage, legacy service-only migration, PTY setup-token capture, validation-before-save, durable explicit routing, method-specific 401 behavior, coherent disconnect, setup-token-first UI, compatibility disclosure, and manual-only `/usage` recovery. The setup-token source gate is enabled on this feature branch solely for user behavioral acceptance.

Per user direction, no tests were added or modified for this implementation and behavioral tests remain with the user. Release approval remains open: signed-app capture, relaunch, locked-Mac read, prompt observation, revocation, cleanup, Light/Dark Settings, and native-menu interaction evidence are recorded as unverified in the capability record. Do not merge as release-ready merely because the compile checks pass.

The first user behavioral pass exposed two implementation defects: capture waited for CLI EOF after token emission, and the shared Disconnect control depended on a confirmation dialog despite the documented immediate-action contract. Both boundaries were corrected on 2026-08-26; their signed-app retest remains open in the capability record.

A follow-up user pass found that OAuth/setup still becomes stuck and Disconnect still has no effect. The first corrections are not accepted as behavioral fixes. Both defects remain open and are deliberately deferred for a later focused diagnosis. This pass only compacts the native menu: when a cached Claude reading exists and the connection has failed, recovery replaces the five-hour/weekly quota card instead of stacking beneath it.

The setup-token callback defect now has a focused successor plan:
[Claude Setup-Token Callback Reliability](./2026-08-28-claude-setup-token-callback-reliability.md).
That plan supersedes this document's five-minute timeout requirement. The
Disconnect defect remains separately deferred.

Implementation update 2026-08-28: the successor plan's 20-minute CLI-owned
authorization lifetime, sanitized progress phases, attempt-safe completion, and
explicit setup cancellation are implemented. Signed-app behavioral acceptance
remains open; Disconnect is still a separate unresolved defect.

## Global Constraints

- Treat [the 2026-08-26 source audit](../../development/claude-usage-monitor-source-audit-2026-08-26.md) as the product decision. “Keychain fallback” means a separately disclosed compatibility action, never an automatic cross-method cascade.
- Preserve the already-implemented prerequisite: a valid status-line snapshot younger than two minutes is returned before any credential read.
- Never ship direct PKCE using Claude Code's client identifier, shell out to `security` as a prompt workaround, mirror Claude Code's credential, schedule `/usage`, or silently switch credential methods.
- Store the setup token only in an App-Owned Claude Credential Keychain item. `UserDefaults` may store only the selected method and other non-secret state.
- Do not log, print, diagnose, persist to a temporary file, place on the clipboard, or attach raw `setup-token` output to an error. Tests construct synthetic values at runtime and never contain a real token.
- Do not perform `SecItem*` calls on `MainActor`. Serialize each Keychain boundary through an actor and make the credential-provider protocol async.
- Use `kSecUseDataProtectionKeychain: true`, a stable service and account, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no synchronizable attribute, update-first/add-second writes, and exhaustive `OSStatus` handling for the App-Owned Claude Credential.
- Treat `errSecInteractionNotAllowed` as a temporary access condition. Do not delete or replace a credential in response; surface a retryable state and retry after the next unlock/user action.
- A rejected App-Owned Claude Credential must lead to explicit reconnect. It must not trigger delegated Claude Code refresh or borrowed-Keychain access.
- Disconnect deletes only the App-Owned Claude Credential and app-owned derived state. It never deletes or modifies Claude Code's credential or provider session.
- Follow [the public update workflow](../../development/public-update-workflow.md). Do not push until the user approves the scope; the user creates the pull request manually.
- Preserve unrelated working-tree changes. The audit/passive-fast-path edits present when this plan was written are prerequisites, not changes to recreate.
- Follow the repository's regression-test rule: add automated coverage only for a deterministic old failure. Adapt existing feature tests as interfaces change; do not add broad presence, routing, or happy-path suites.

---

## Accepted Source Policy

```text
automatic refresh
    |
    +-- fresh Passive Claude Usage Snapshot (< 2 minutes) --> serve, no credential read
    |
    +-- explicitly selected authoritative credential
    |       +-- App-Owned Claude Credential (normal primary)
    |       `-- Borrowed Claude Code Credential (compatibility mode only)
    |
    +-- best local status-line snapshot or cached authoritative result
    `-- unavailable with a specific recovery action

explicit recovery only
    +-- Reconnect with setup-token
    +-- Use Claude Code credentials… (may prompt)
    `-- Force read with Claude /usage (may consume quota)
```

There is no edge from a failed setup-token read to a borrowed credential read, and no edge from an automatic refresh to `/usage`.

## Architecture Fit

**MVVM fit:** Keep the current architecture. The feature has moderate screen state and several injected effects, but it does not justify a new reducer framework or a repository-wide Observation migration. `QuotaViewModel` remains the main-actor presentation owner; credential selection, Keychain access, PTY capture, and usage HTTP calls stay in injected services/actors. Views render state and forward actions only.

**Ownership rules:**

- `ClaudeCredentialSelectionStore` owns one non-secret preference: the selected authoritative credential method.
- `ClaudeCompositeCredentialStore` owns the in-memory routing decision and never chooses an alternate method itself.
- `ClaudeSelfIssuedCredentialStore` owns only the App-Owned Claude Credential item.
- `ClaudeKeychainCredentialStore` owns only reads of Claude Code's item and applies the prompt policy on every request.
- `ClaudeSetupTokenCapture` owns one cancellable CLI process and its PTY descriptors.
- `ClaudeSetupTokenService` owns the transaction: capture, validate, persist, then return the proven account summary.
- `ClaudeConnectionController` publishes `.connected` only after method activation is durable and visible to the monitor.
- `ClaudeUsageCollector` owns the passive/authoritative/cache order and method-specific rejection recovery.

## File Map

### Create

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCredentialSelectionStore.swift` — durable non-secret selected-method preference and one-time compatibility migration.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenAvailability.swift` — one release gate, false until the signed-app capability matrix passes.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift` — PTY-backed, cancellable, in-memory-only setup-token capture.
- `docs/development/claude-auth-capability-results.md` — signed-app gate evidence containing no credential material.

### Modify

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift` — async provider contract, typed Keychain errors, actor-isolated borrowed store.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSelfIssuedCredentialStore.swift` — actor isolation and hardened data-protection Keychain CRUD.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift` — mutable selected-method router with no default and no implicit alternate.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionState.swift` — rename `.browser` to `.setupToken` and update factual states/copy.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift` — setup-token naming, awaited method activation, cancellation, and disconnect cleanup.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenService.swift` — injected PTY capture, validate-before-save transaction, no environment adoption.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift` — await credential resolution and preserve effective method on rejection.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift` — setup-token invalidation versus borrowed delegated refresh.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift` — remove production default construction that silently selects borrowed credentials.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — live dependency assembly, primary connect action, compatibility action, and coherent disconnect.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeCredentialActions.swift` — primary reconnect plus compatibility action.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift` — method-specific recovery copy.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeSignInPresentation.swift` and `ClaudeSignInView.swift` — setup-token terminology and prompt disclosure.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift` — pass distinct primary and compatibility actions.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift` — source selection/recovery controls and `/usage` copy.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeSetupOnboardingView.swift` — setup-token-first onboarding.
- Existing Claude credential, setup-token, connection-controller, OAuth-source, collector, and presentation tests — adapt interfaces and add only defect regressions listed below.
- `README.md`, `UsageProbe/README.md`, `docs/development/authentication-and-usage-collection.md`, `docs/development/operating-notes.md`, `docs/product/follow-ups.md`, and `docs/product/planning-board.md` — describe the shipped hierarchy and evidence status.

---

## Task 0 — Freeze the prerequisite baseline

- [ ] Read `AGENTS.md`, `docs/development/public-update-workflow.md`, this plan, the source audit, and the two 2026-08-12 Claude plans before editing production code.
- [ ] Confirm the working tree and preserve the audit/passive-fast-path work:

  ```bash
  git status --short
  git diff -- CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift
  git diff -- CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift
  ```

  Expected: the status-line fast path precedes OAuth, and the composite store does not automatically try the alternate method.

- [ ] Run and record the pre-change narrow baseline from `CodexUsageMonitor/`:

  ```bash
  swift test --filter ClaudeUsageCollectorTests
  swift test --filter ClaudeCompositeCredentialStoreTests
  swift test --filter ClaudeSelfIssuedCredentialStoreTests
  swift test --filter ClaudeSetupTokenServiceTests
  swift test --filter ClaudeConnectionControllerTests
  ```

  Expected: every command exits 0. If a prerequisite test fails, diagnose it before this plan proceeds.

- [ ] Run `swift test` once and record any pre-existing failure in the capability-results document. At plan-writing time, `ClaudeUsageMonitorTests.testReconnectResumesReading` was an unrelated known failure; do not silently claim a green full suite or fold its repair into credential work without proving it blocks this feature.

- [ ] Create the implementation branch only after the current public-main prerequisite changes are approved and integrated, following the public update workflow.

---

## Task 1 — Harden the App-Owned Claude Credential boundary

### Step 1.1: Make credential loading async and actor-isolated

- [ ] Change `ClaudeCredentialProviding` to:

  ```swift
  protocol ClaudeCredentialProviding: Sendable {
      func loadCredential(
          promptPolicy: KeychainPromptPolicy
      ) async throws -> ClaudeOAuthCredential
  }
  ```

- [ ] Make `ClaudeOAuthCredential`, `ClaudeCredentialResolution`, and `ClaudeCredentialError` explicitly `Sendable` so their value-only data can cross the credential actors without an unchecked conformance.
- [ ] Convert `ClaudeSelfIssuedCredentialStore`, `ClaudeKeychainCredentialStore`, and `ClaudeCompositeCredentialStore` themselves to actors. Update `ClaudeOAuthUsageSource.fetch` to `await` credential loading.
- [ ] Delete `ClaudeEffectiveMethodRecorder` and return a typed `ClaudeCredentialResolution` from the router. Do not add `@unchecked Sendable` merely to satisfy the compiler.
- [ ] Ensure actor methods make no state assumption across an `await`. Capture the selected method in a local before awaiting its provider, then report that same method with the result.

### Step 1.2: Replace delete-then-add with a data-protection item

The current write has a reproducible credential-loss window:

```swift
// ❌ Current anti-pattern: a failed add leaves no credential.
deleteKeychainData(serviceName: serviceName)
let status = SecItemAdd(addQuery(service: serviceName, data: data) as CFDictionary, nil)
```

Implement this contract instead:

```swift
// ✅ Required attributes and update-first behavior.
static let defaultService = "AgentUsageMonitor-ClaudeOAuth"
static let defaultAccount = "setup-token-v1"

static func baseQuery(service: String, account: String) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecUseDataProtectionKeychain as String: true,
    ]
}

static func addAttributes(data: Data) -> [String: Any] {
    [
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
}
```

- [ ] `save` first calls `SecItemUpdate(baseQuery, addAttributes)`. On `errSecItemNotFound` only, merge those dictionaries and call `SecItemAdd`. On `errSecDuplicateItem`, retry one update because another process/version may have created the item between calls. No path deletes first.
- [ ] `load` uses the stable service/account/data-protection query plus `kSecReturnData` and `kSecMatchLimitOne`. Do not include `kSecAttrAccessible` in the search query.
- [ ] `delete` uses the stable service/account/data-protection query and treats only `errSecSuccess` and `errSecItemNotFound` as success.
- [ ] Extend `ClaudeCredentialError` so callers can distinguish `.notFound`, `.malformedData`, `.interactionNotAllowed`, `.accessDenied`, and `.unexpectedStatus(OSStatus)` without including secret data.
- [ ] Use this status matrix for copy, retry, and tests:

  | Operation result | Domain result | Mutation allowed |
  |---|---|---|
  | `errSecSuccess` | success | yes |
  | `errSecItemNotFound` on load | `.notFound` | no |
  | `errSecItemNotFound` on update | attempt add | yes |
  | `errSecInteractionNotAllowed` | `.interactionNotAllowed` | no |
  | `errSecAuthFailed` / denied | `.accessDenied` | no |
  | any other status | `.unexpectedStatus(status)` | no further mutation |

- [ ] Keep `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: scheduled reads need access while the Mac is locked after its first unlock, while `ThisDeviceOnly` prevents backup migration. Before first unlock, surface a temporary unavailable state and retry later.
- [ ] Omit `kSecAttrSynchronizable`, access groups, biometric access control, and application-password prompts. They conflict with unattended scheduled reads or unnecessarily widen credential access.

### Step 1.3: Handle the pre-release unscoped item safely

- [ ] On a scoped-item miss, look once for the legacy service-only item created by the current pre-release code.
- [ ] If found, decode it, save it under the new stable service/account/data-protection query, verify the new item can be read, then delete the legacy item. If the new save or verification fails, leave the legacy item untouched.
- [ ] Do not migrate `CLAUDE_CODE_OAUTH_TOKEN` from the process environment. Remove environment lookup from normal GUI reads and setup; it is neither a durable login nor an explicit user action.

### Step 1.4: Add only deterministic defect regressions

- [ ] Adapt `ClaudeSelfIssuedCredentialStoreTests` to async actor calls.
- [ ] Add a regression proving a failed update/add never invokes delete and never destroys the fake's previous value. This protects the current delete-before-add defect.
- [ ] Add a regression proving `errSecInteractionNotAllowed` performs no write/delete and maps to the temporary domain error.
- [ ] Update the existing query-attribute assertion to require service, account, data-protection Keychain, explicit accessibility on add, and no synchronizable attribute.
- [ ] Add a migration regression proving the legacy item is deleted only after the new item round-trips successfully.
- [ ] Keep real user Keychain access out of unit tests. Reserve one signed-app integration check for Task 4 with a dedicated item and guaranteed cleanup.

### Step 1.5: Verify and checkpoint

```bash
cd CodexUsageMonitor
swift test --filter ClaudeSelfIssuedCredentialStoreTests
swift test --filter ClaudeKeychainCredentialStoreTests
swift test --filter ClaudeOAuthUsageSourceTests
```

Expected: all selected tests exit 0; no test touches a real Keychain item.

Commit only this boundary:

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSelfIssuedCredentialStore.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeSelfIssuedCredentialStoreTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeKeychainCredentialStoreTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift
git commit -m "fix: harden app-owned Claude credential storage"
```

---

## Task 2 — Replace pipe capture with a cancellable PTY transaction

### Step 2.1: Introduce a narrow capture boundary

- [ ] Create `ClaudeSetupTokenCapture.swift` with one protocol and one live actor. The public contract returns only the extracted token value or a typed non-secret error:

  ```swift
  protocol ClaudeSetupTokenCapturing: Sendable {
      func capture() async throws -> String
  }
  ```

- [ ] Implement `ClaudeSetupTokenCapture` as an actor conforming to that protocol; the actor owns its single live process and PTY descriptors.
- [ ] The live actor locates the official `claude` executable, launches `claude setup-token` attached to a Darwin PTY, and reads the PTY master incrementally. It must not accumulate the full transcript.
- [ ] Keep an 8 KiB sliding buffer so a token split across PTY chunks can be detected. Starting at `sk-ant-oat01-`, accept only ASCII letters, digits, hyphen, and underscore; stop at whitespace, quotes, terminal punctuation, EOF, or process exit. Once complete, retain only that token and discard preceding output.
- [ ] Close master/slave descriptors on success, error, cancellation, and process exit. Use `withTaskCancellationHandler` so cancelling connection terminates only the process started by this capture and closes its descriptors.
- [ ] Set a five-minute timeout. Map timeout, user cancellation, missing CLI, non-zero exit, and missing token to `.timedOut`, `.cancelled`, `.missingCLI`, `.setupTokenFailed`, and `.tokenNotFoundInOutput`; none carries stdout/stderr.
- [ ] Do not use `Task.detached`, a shell, a temporary file, `tee`, the clipboard, or `Process.waitUntilExit()` on `MainActor`.

### Step 2.2: Make setup validation transactional

- [ ] Inject `any ClaudeSetupTokenCapturing` and `any ClaudeSelfIssuedCredentialStoring` into `ClaudeSetupTokenService`.
- [ ] Remove GUI environment-token adoption and the paste-token affordance from production. A developer test may inject a synthetic capture result through the protocol.
- [ ] Preserve validate-before-save order:

  ```text
  PTY captures candidate in memory
      -> usage endpoint validates candidate
      -> app-owned Keychain save succeeds
      -> selected method is activated
      -> connection becomes connected
  ```

- [ ] If validation or save fails, do not change the selected method, enrollment, or connection state. Return a typed recovery state and let the candidate fall out of scope. Do not claim guaranteed memory zeroization for Swift `String`; minimize copies and lifetime instead.
- [ ] Keep `ClaudeOAuthCredential` non-Codable and non-printable. No new credential type may conform to `CustomStringConvertible`, `CustomDebugStringConvertible`, or `LocalizedError` with associated secret text.

### Step 2.3: Adapt existing tests and add leak/cancellation regressions

- [ ] Replace the current `setupTokenRunner: () throws -> String` fixtures with an injected capture fake.
- [ ] Build synthetic tokens as `ClaudeSetupTokenService.tokenPrefix + "fixture-token-value"`; remove full token-looking literals from fixtures.
- [ ] Preserve the existing regression proving validation happens before persistence and rejected candidates never enter the store.
- [ ] Preserve the existing regression proving thrown errors do not contain the candidate.
- [ ] Add one deterministic cancellation regression for the current uninterruptible process behavior: a suspended fake capture observes cancellation, returns `CancellationError`, and the service performs no validation or save.
- [ ] Adapt the existing noisy-output parser regression to feed the same synthetic value across multiple chunks, including a split inside the prefix. Do not add a separate broad parser suite.

### Step 2.4: Verify and checkpoint

```bash
cd CodexUsageMonitor
swift test --filter ClaudeExecutableLocatorTests
swift test --filter ClaudeSetupTokenServiceTests
```

Expected: all selected tests exit 0 with no process launch and no real Keychain access.

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenService.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeSetupTokenServiceTests.swift
git commit -m "feat: capture Claude setup token securely"
```

---

## Task 3 — Persist the chosen method and assemble one live credential graph

### Step 3.1: Name the methods accurately

- [ ] Rename `ClaudeSignInMethod.browser` to `.setupToken`. Keep `.claudeCodeCredentials` for compatibility mode.
- [ ] Use stable persisted values independent of Swift case spelling:

  ```swift
  enum ClaudeSignInMethod: String, Codable, Sendable {
      case setupToken = "setup-token"
      case claudeCodeCredentials = "claude-code-credentials"
  }
  ```

- [ ] Update presentation names to “Agent Monitor credential” or “Claude Code credentials”; do not call setup-token “browser OAuth” or imply the two methods are co-equal defaults.

### Step 3.2: Add the non-secret selection store

- [ ] Create a `@MainActor` `ClaudeCredentialSelectionStore` using the key `claude.credential-method.v1`.
- [ ] Expose `selectedMethod`, `select(_:)`, and `clear()`. Store only the enum raw value in `UserDefaults`; never store token data, account metadata, scopes, or a credential fingerprint.
- [ ] Fresh installs default to `nil`. For an upgrade with Claude enrollment already enabled and no selection key, migrate once to `.claudeCodeCredentials`, because every previously shipped Claude Connect action explicitly selected that method. Record the migrated key so the inference is never repeated.
- [ ] An unknown persisted value resolves to `nil` and presents setup again; it must not default to borrowed access.
- [ ] On a fresh install or cleared selection, remove any orphaned App-Owned Claude Credential before presenting setup. This prevents a Keychain item that survived uninstall from silently reconnecting a new installation. Never touch Claude Code's credential.

### Step 3.3: Make the composite store a router, not a fallback chain

- [ ] `ClaudeCompositeCredentialStore` owns `ClaudeSignInMethod?` and exposes actor methods to select, clear, resolve, and invalidate the App-Owned Claude Credential.
- [ ] With no selected method, resolution throws `.notFound`. With a selected method, it calls exactly one provider.
- [ ] Return `ClaudeCredentialResolution(credential:method:)` so the OAuth layer and collector know which method actually produced a rejected credential without a lock-based side channel.
- [ ] Remove the default `.claudeCodeCredentials` initializer. Any production construction without an explicit selection must fail to compile.

### Step 3.4: Assemble shared live dependencies in `QuotaViewModel`

- [ ] Build one selection store, one self-issued store, one borrowed store, and one composite router before constructing `ClaudeOAuthUsageSource` and `ClaudeUsageMonitor`.
- [ ] Pass that same router to connection and monitor flows. Do not create a fresh `ClaudeCompositeCredentialStore()` inside `credentialsSignIn`, `ClaudeUsageMonitor` defaults, or refresh actions.
- [ ] Replace the disabled `browserSignIn` closure with `ClaudeSetupTokenService.connect()`.
- [ ] Make `ClaudeConnectionController` await method activation before it publishes `.connected`; this prevents the connected-state sink from refreshing through the old method.
- [ ] On setup-token success: select `.setupToken`, enable Claude enrollment, reconnect the monitor, publish connected, then refresh once.
- [ ] On compatibility success: select `.claudeCodeCredentials`, enable enrollment, publish connected, then refresh once.
- [ ] On a failed connect, leave the former working method selected if one exists. A user retry must not erase a valid credential before the replacement is proven.

### Step 3.5: Adapt existing regression coverage

- [ ] Update `ClaudeCompositeCredentialStoreTests` to async actor calls and preserve the current no-alternate-read regression for both method directions.
- [ ] Adapt the existing `onMethodSelected` controller test to keep asserting that selection occurs only after successful sign-in and before consumers act on `.connected`; do not create a new routing test suite.
- [ ] Record the shipped upgrade migration and fresh-install orphan cleanup as manual regression boundaries unless execution reproduces a deterministic failure suitable for the repository's defect-only test policy.
- [ ] Update OAuth source and collector fakes for async credential loading without time-based waits.

### Step 3.6: Verify and checkpoint

```bash
cd CodexUsageMonitor
swift test --filter ClaudeCompositeCredentialStoreTests
swift test --filter ClaudeConnectionControllerTests
swift test --filter ClaudeOAuthUsageSourceTests
swift test --filter ClaudeUsageCollectorTests
```

Expected: all selected tests exit 0; neither setup-token failure nor missing selection records a borrowed read.

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCredentialSelectionStore.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionState.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeCompositeCredentialStoreTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeConnectionControllerTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift
git commit -m "feat: route Claude usage through selected credentials"
```

---

## Task 4 — Pass the signed-app setup-token capability gate

Do not expose setup-token as the primary release action until every required observation below passes. Create `ClaudeSetupTokenAvailability.swift` with `static let isEnabled = false`, and use the same production services when that source-level gate is locally enabled.

- [ ] Create `docs/development/claude-auth-capability-results.md` with sections: Environment, CLI Version, Capture, Validation, Relaunch, Locked-Mac Read, Revocation/401, Cleanup, Prompt Observation, and Decision.
- [ ] Record the exact `claude --version`, macOS version, app build, signing identity summary, and date. Record no email, organization, token, response body, raw CLI output, or Keychain item data.
- [ ] Build the signed app from `CodexUsageMonitor/`:

  ```bash
  ./Scripts/build-app.sh
  ```

  Expected: the script exits 0 and produces the signed `.app` used for every gate observation.

- [ ] With the user present, locally enable the guarded setup action and press **Connect with Claude** once. Confirm Claude Code opens its supported flow, the PTY capture completes, usage validation returns a 200 with at least one usage window, and no raw token appears in Console or app diagnostics.
- [ ] Quit only the app instance started for this audit. Relaunch the same signed app normally and perform a scheduled/non-user-initiated authoritative read from the App-Owned Claude Credential. Confirm it succeeds without a cross-app Keychain prompt.
- [ ] After the Mac has been unlocked once, lock it while the app remains running and allow one normal refresh. Confirm the data-protection item remains readable and the app does not prevent system sleep. If the test occurs before first unlock and returns `errSecInteractionNotAllowed`, confirm the item is retained and a later retry succeeds.
- [ ] Exercise a rejected/revoked synthetic or deliberately invalid candidate before storage and confirm it is not saved. Do not revoke the user's real token merely to manufacture this state.
- [ ] Disconnect, verify the app-owned item is removed, and verify Claude Code remains signed in and its own Keychain item remains untouched.
- [ ] Inspect Console and the app's diagnostics/export output for the token prefix and captured transcript. Expected: no credential or raw setup output appears.
- [ ] Set the release availability gate to true only if capture, validation, relaunch, non-prompting read, and cleanup all pass. If any fails, leave setup-token unavailable, record the failure, and ship only the already-disclosed borrowed compatibility path plus passive/forced sources; do not weaken storage or capture to force a pass.

Checkpoint the evidence separately:

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenAvailability.swift \
  docs/development/claude-auth-capability-results.md
git commit -m "feat: enable verified Claude setup-token flow"
```

---

## Task 5 — Make rejection and disconnect method-specific

- [ ] Carry the effective credential method through `ClaudeOAuthUsageSource` so a 401/403 is not method-ambiguous.
- [ ] When `.setupToken` is rejected:

  1. delete the App-Owned Claude Credential through its actor;
  2. retain `.setupToken` as the desired method so the UI says **Reconnect Claude**;
  3. do not call delegated refresh;
  4. do not read Claude Code's Keychain item;
  5. serve a passive snapshot/cache if available, labelled with its source and age.

- [ ] When `.claudeCodeCredentials` is rejected, retain the existing delegated Claude Code refresh behavior and its cooldown. A retry uses the same borrowed method and prompt policy; it never creates an App-Owned Claude Credential.
- [ ] After the first user-initiated borrowed read, run any post-delegated-refresh retry with `.never`. This preserves the one-system-prompt-per-button-press contract even when the user chose macOS's one-time **Allow** action.
- [ ] When Keychain returns `.interactionNotAllowed`, keep the item and selected method, show a temporary availability message, and retry only after a later scheduled/user event.
- [ ] On Disconnect, cancel connection/capture work, await deletion of the App-Owned Claude Credential if it is selected or present, clear selected method and app enrollment, stop the monitor, purge app-derived Claude caches under the existing privacy policy, and leave Claude Code's provider session/credential untouched.
- [ ] If app-owned deletion fails, show a recoverable local-storage error instead of reporting disconnect as complete. Do not swallow the `OSStatus`.
- [ ] Adapt the existing no-alternate-read and delegated-refresh regressions to cover method-specific rejection. The Task 1 interaction-not-allowed regression remains the automated deletion guard. Record disconnect deletion-failure behavior as a manual boundary unless execution reproduces a deterministic old failure permitted by repository policy.

Verify:

```bash
cd CodexUsageMonitor
swift test --filter ClaudeUsageCollectorTests
swift test --filter ClaudeConnectionControllerTests
swift test --filter ClaudeSelfIssuedCredentialStoreTests
```

Expected: all selected tests exit 0.

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSelfIssuedCredentialStore.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeConnectionControllerTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeSelfIssuedCredentialStoreTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeOAuthUsageSourceTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageCollectorTests.swift
git commit -m "fix: make Claude credential recovery method-specific"
```

---

## Task 6 — Ship setup-token-first UI and explicit recovery copy

### Step 6.1: Primary setup and compatibility disclosure

- [ ] Keep `QuotaViewModel` as the intent owner. Views receive separate closures named `connectClaudeWithSetupToken` and `connectClaudeWithCredentials`; views do not construct services or mutate preference stores.
- [ ] Update `ClaudeSetupOnboardingView` to this hierarchy:

  - Title: **Set up Claude usage**
  - Body: **Claude Code opens sign-in and creates a long-lived token for Agent Monitor. Agent Monitor stores it in its own Keychain item and does not read Claude Code’s credential.**
  - Primary button: **Connect with Claude**
  - Secondary action: **Use Claude Code credentials…**
  - Secondary disclosure: **Reads the OAuth credential stored by Claude Code. Because it belongs to another app, macOS may ask for Keychain access now and again later.**

- [ ] Do not offer a paste-token field or instruct users to put a token on the clipboard.
- [ ] Update setup-token states with specific recovery actions:

  | State | Message | Action |
  |---|---|---|
  | CLI missing | “Claude Code is required to connect this way. Install or update Claude Code, then try again.” | **Try Again** plus compatibility action |
  | user cancelled | “Claude sign-in was cancelled. No credential was saved.” | **Connect with Claude** |
  | token rejected | “Claude did not accept the new credential. Connect again to create another one.” | **Reconnect Claude** |
  | Keychain unavailable | “Agent Monitor could not save the Claude credential in Keychain.” | **Try Again** |
  | before first unlock | “Claude usage will resume after this Mac is unlocked.” | no destructive action |
  | borrowed denied | preserve the explicit macOS Keychain recovery guidance | **Use Claude Code credentials…** |

### Step 6.2: Settings source/recovery controls

- [ ] In `ClaudeAgentSettingsView`, show the active authoritative method in a wrapping `SettingsValueRow`; never put variable text in a fixed-width trailing control.
- [ ] Keep passive capture in the Source section with this factual note: **Fresh Claude Code status-line data can update usage without reading any credential.**
- [ ] Rename the force row to **Claude /usage** and the button to **Force Read**. Use this description: **Runs claude -p /usage once. It may use a small amount of Claude quota; automatic refresh never runs it.**
- [ ] Keep the existing first-use confirmation, but remove the unsupported precise dollar estimate unless it is reverified from current official Anthropic documentation during implementation.
- [ ] Keep compatibility access visually secondary and use an ellipsis because it can open a system permission interaction.

### Step 6.3: Menu recovery without geometry churn

- [ ] Update `ClaudeCredentialActions` and `ClaudeConnectionRecoveryCard` so a failed App-Owned Claude Credential offers **Reconnect Claude** first and **Use Claude Code credentials…** second.
- [ ] Do not add `/usage` to the native menu in this change. It remains in Settings, which avoids new menu rows and accidental activation of a quota-consuming action.
- [ ] Keep native-menu row identity and width stable across signing, success, failure, and recovery. Publish semantic transitions only; add no timer, timeline, or per-second invalidation.

### Step 6.4: SwiftUI/layout/accessibility acceptance

- [ ] Use `SettingsSection`, `SettingsSectionRow`, `SettingsPreferenceControlRow`, `SettingsValueRow`, and `SettingsDescription`; do not add a top-level `Form`, `LabeledContent`, duplicated geometry constants, or transparent spacer views.
- [ ] Extract materially new subviews rather than lengthening `ClaudeAgentSettingsView.body` with nested conditional builders.
- [ ] Use native text-bearing `Button`s, system foreground styles, callout-or-larger recovery text, wrapping descriptions, and accessible input labels for changing button titles.
- [ ] Preserve the stable Settings presentation host and provider-intrinsic height. Do not add `.id`, a fixed content floor, or a window-level selection owner.
- [ ] At the default 680 × 560 Settings size, inspect the Claude page with Context Rail hidden and visible in Light and Dark. Cover first-run, connecting, success, missing CLI, rejected token, borrowed permission denied, absent quota, long source text, and forced-read error.
- [ ] Inspect the signed native menu across setup-token success/failure and borrowed compatibility selection. Point, click, keyboard-navigate, and reopen repeatedly; verify visible highlight and activation remain aligned.

### Step 6.5: Verify and checkpoint

```bash
cd CodexUsageMonitor
swift test --filter ClaudeSignInPresentationTests
swift test --filter ClaudeSetupStateTests
xcodebuild -scheme CodexUsageMonitor \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AgentUsageMonitor-ClaudeSetupToken build
./Scripts/build-app.sh
```

Expected: each command exits 0, then the signed-app visual matrix is recorded in the capability-results document.

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeCredentialActions.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeSignInPresentation.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeSignInView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeSetupOnboardingView.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeSignInPresentationTests.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeSetupStateTests.swift
git commit -m "feat: make setup token the primary Claude connection"
```

---

## Task 7 — Update user-facing documentation and operating boundaries

- [ ] Update `README.md` so the normal source order is: fresh status-line snapshot, selected authoritative credential (setup-token primary), best local/cache fallback, then explicit recovery.
- [ ] Update `UsageProbe/README.md` to distinguish the probe's explicit credential/source options from the GUI's persisted App-Owned Claude Credential. Do not imply the probe or environment is a login mechanism.
- [ ] Update `docs/development/authentication-and-usage-collection.md` with the stable service/account, accessibility class, method-selection key, migration, 401 behavior, disconnect cleanup, and no-automatic-fallback rule.
- [ ] Update `docs/development/operating-notes.md` with install/update requirements for Claude Code, setup/reconnect steps, borrowed-Keychain prompt expectations, and the Forced Claude Usage Read consent boundary.
- [ ] Update Data & Privacy copy in the app if its current inventory still says the app only reads Claude Code's item. State that the app stores one long-lived token in its own device-bound Keychain item when setup-token is selected; exports and diagnostics never include it.
- [ ] Keep the existing unsupported/private-endpoint and terms caveat for `/api/oauth/usage`. App ownership of a token does not make that endpoint a published third-party contract.
- [ ] Update follow-up 12 and the planning board to implementation/verification status with a link to the capability record. Do not close them until relaunch, prompt, cleanup, and signed UI evidence are complete.
- [ ] Mark the 2026-08-12 prompt-free plan as superseded for execution sequencing, but keep it as historical research and prompt-contract evidence.

Checkpoint:

```bash
git add README.md UsageProbe/README.md \
  docs/development/authentication-and-usage-collection.md \
  docs/development/operating-notes.md \
  docs/product/follow-ups.md docs/product/planning-board.md \
  docs/superpowers/plans/2026-08-12-claude-prompt-free-credentials.md \
  docs/development/claude-auth-capability-results.md
git commit -m "docs: explain Claude setup-token and recovery sources"
```

---

## Task 8 — Final verification and handoff

### Automated verification

Run from `CodexUsageMonitor/`:

```bash
swift test --filter ClaudeSelfIssuedCredentialStoreTests
swift test --filter ClaudeKeychainCredentialStoreTests
swift test --filter ClaudeSetupTokenServiceTests
swift test --filter ClaudeCompositeCredentialStoreTests
swift test --filter ClaudeConnectionControllerTests
swift test --filter ClaudeOAuthUsageSourceTests
swift test --filter ClaudeUsageCollectorTests
swift test --filter ClaudeSignInPresentationTests
swift test
xcodebuild -scheme CodexUsageMonitor \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AgentUsageMonitor-ClaudeSetupToken-Final build
./Scripts/build-app.sh
```

Expected: all narrow tests, the full suite, Xcode build, and signed-app build exit 0. If the known unrelated monitor test still fails, report it precisely and do not claim full-suite success; determine whether repository policy requires resolving it before the branch is ready.

Run from the repository root:

```bash
git diff --check
gitleaks detect --source . --no-git --redact
```

Expected: both commands exit 0. If `gitleaks` is unavailable, run the repository's configured secret scanner and record the exact limitation; do not replace it with a token-printing search.

### Signed-app behavioral matrix

- [ ] Fresh status-line snapshot: served without an App-Owned or Borrowed credential read.
- [ ] Setup-token first connection: one user action, supported Claude flow, validated save, connected state.
- [ ] Relaunch: authoritative read works from the App-Owned Claude Credential with no Claude Code Keychain prompt.
- [ ] Scheduled, wake, activation, and menu-open reads: never show a prompt.
- [ ] Locked after first unlock: refresh succeeds or cleanly defers without deleting the item; app does not create a sleep-prevention assertion.
- [ ] Setup-token 401/403: App-Owned Claude Credential invalidated, explicit reconnect shown, no borrowed read/delegated refresh.
- [ ] Borrowed compatibility: disclosure shown first, at most one system prompt per user action, no automatic prompt later.
- [ ] `/usage`: never automatic, first-use consent shown, one forced reading applied coherently, failure visible.
- [ ] Disconnect: app-owned token and derived app state removed; Claude Code remains signed in and its credential untouched.
- [ ] Source labels: passive, App-Owned credential, Borrowed credential, CLI, and cache are distinguishable and include age where applicable.
- [ ] Light/Dark, Context Rail hidden/visible, keyboard, pointer, VoiceOver, long copy, and absent-value Settings states inspected in the signed app.
- [ ] Native menu rows keep correct geometry, highlight, keyboard activation, and repeated open/close behavior across all new semantic states.

### Documentation and PR handoff

- [ ] Update this plan's checkboxes and the capability record with actual commands/results; do not infer unobserved evidence.
- [ ] Review the final diff for unrelated changes and credential material.
- [ ] Use `preparing-evidence-rich-prs` to generate a filled draft from `.github/pull_request_template.md`, including the compare URL and exact automated/manual evidence.
- [ ] Push only after user approval. Do not create the GitHub pull request.

## Explicitly Out of Scope

- Direct Agent Monitor PKCE/OAuth until Anthropic publishes a third-party contract or issues this app a client registration.
- Automatic setup-token-to-borrowed-Keychain fallback.
- Scheduled or menu-open `/usage` execution.
- Mirroring, refreshing, rewriting, or deleting Claude Code's credential.
- Restoring a dynamic native-menu countdown.
- Consolidating the separate Claude status-line bridge executable.
- Fixing unrelated monitor/reconnect tests unless they are proven to block this feature's verification.
- Changing signing, entitlements, bundle identifiers, deployment targets, build settings, or app-sandbox capabilities to make the feature pass.

## Rollback Plan

- If setup-token capture or relaunch validation fails, leave the availability gate false and retain passive capture, explicit Borrowed Claude Code Credential compatibility, cache, and Forced Claude Usage Read.
- If the new selected-method migration misclassifies an upgraded user, clear only `claude.credential-method.v1`; do not delete Claude Code's item. The UI returns to explicit setup selection.
- If the App-Owned Claude Credential schema must roll back, keep the stable service/account readable by the previous release or add a read-compatible migration before shipping. Never delete first.
- If the UI introduces Settings or native-menu geometry regressions, revert only the presentation commit while keeping the hardened credential services gated and unreachable.

## Reference Files

- `/Users/David/.codex/skills/swift-security-expert/references/keychain-fundamentals.md` — supplied the stable service/account query model, data-protection Keychain requirement, add-or-update pattern, and exhaustive `OSStatus` handling.
- `/Users/David/.codex/skills/swift-security-expert/references/keychain-access-control.md` — supplied the explicit accessibility-class decision and the rule that interaction-not-allowed is non-destructive and retryable.
- `/Users/David/.codex/skills/swift-security-expert/references/credential-storage-patterns.md` — supplied actor serialization, device-bound credential lifecycle, logout cleanup, and secret-scanning requirements.
- `/Users/David/.codex/skills/swift-security-expert/references/testing-security-code.md` — supplied protocol-backed fakes, real-Keychain isolation/cleanup, injected error-path tests, and CI limitations.
