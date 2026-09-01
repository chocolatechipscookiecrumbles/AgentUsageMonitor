# Claude Keychain Reprompt Durability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Use `swift-security-expert` for the Keychain query and error boundary, `systematic-debugging` and `diagnosing-bugs` for the transition gate, `swift-concurrency-pro` for actor ownership, `writing-for-interfaces` for recovery copy, and `verification-before-completion` before any completion claim. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Agent Monitor honor macOS **Always Allow** across sleep, relaunch,
and ordinary Claude credential updates, while preventing an inconclusive
background failure from sending the user through another permission prompt.

**Architecture:** Keep Claude Code's credential provider-owned and read-only. Narrow `SecItemCopyMatching` to the single default/login Keychain instead of inheriting the machine's duplicated global search list. Treat automatic collection as a data-source concern: a noninteractive Keychain failure may make OAuth unavailable, but it must not change the user's persisted connection state or claim authorization was revoked. A controlled transition observation determines whether Claude Code changes only the value/persistent item or also replaces its access object; the app never edits the provider's ACL.

**Tech Stack:** Swift 6.2, Security framework `SecItemCopyMatching`, legacy macOS `SecKeychain` search scoping for the provider-owned login-Keychain item, LocalAuthentication `LAContext`, Swift Concurrency actors, Combine, unified logging, Swift Package Manager, and the repository's signed-app build script.

## Global Constraints

- A value-only update should preserve the Keychain item's trusted-application ACL. Treat a new prompt after **Always Allow** as a defect until evidence proves the provider replaced the item or access object.
- Agent Monitor never stores, copies, refreshes directly, changes, deletes, exports, logs, or edits ACLs for `Claude Code-credentials`.
- Only **Connect Claude** or **Reconnect Claude** may permit authentication UI. Launch, scheduled refresh, ordinary Refresh, wake recovery, probes, and retries remain noninteractive.
- During a `.never` read, `errSecInteractionNotAllowed` and `errSecAuthFailed`
  mean only “OAuth unavailable without interaction.” They never mean
  “permission revoked,” never disconnect Claude, and never authorize a prompt.
- Only the explicit Connect/Reconnect transaction may classify a user denial or
  failed interactive ACL read as authorization failure. Keep missing entitlement
  and every other `OSStatus` typed and non-secret instead of presenting them as
  a user permission choice.
- Continue the accepted source order: fresh passive snapshot → noninteractive OAuth → freshest older passive/cache → explicit cost-disclosed `/usage`.
- The provider-owned item intentionally remains in Claude Code's legacy login Keychain. Do not add `kSecUseDataProtectionKeychain`; doing so targets a different store and makes the real item undiscoverable.
- Do not normalize or otherwise mutate the user's global Keychain search list in this implementation.
- Do not add or run automated test cases in this follow-up, preserving the user's current test boundary. Use implementer-owned sanitized diagnostics, production builds, and user-owned signed-app behavior acceptance.
- Do not log credential bytes, account attributes, persistent references, raw queries, callback material, or provider responses. Diagnostic evidence may contain only `OSStatus`, timestamps, counts, booleans, query scope names, refresh reason, and sanitized source/delivery state.
- Execute on a short-lived public-repository branch. If `feat/claude-setup-token-primary` has not merged, make this a clearly based stacked branch and target that parent; otherwise start from current `origin/main` per `docs/development/public-update-workflow.md`.

---

## Evidence and Current Diagnosis

The following observations were made without reading or printing credential data:

1. `securityd` recorded three ACL prompts for the same still-running process and path. Each prompt was followed by “user approved 'always allow',” yet a later prompt appeared for that same PID. Process replacement, restart into another path, and a changed code signature therefore do not explain those repetitions.
2. The working-copy app and installed app share the same Developer ID designated requirement. Both currently complete the sanitized noninteractive OAuth probe.
3. The user Keychain search list contains the same `login.keychain-db` path 168 times. An attributes-only `SecItemCopyMatching` inherited that list and returned the same Claude item 168 times. The same query with `kSecMatchSearchList` restricted to the default Keychain returned one item.
4. The Claude item's creation date remains unchanged while its modification date advances, ruling out ordinary delete-and-add replacement. The latest observed update preceded a new ACL prompt by about six minutes; whether the same update also changed the access object remains unproven.
5. The current app collapses `ClaudeCredentialError.interactionNotAllowed` and `.accessDenied` into one `ClaudeOAuthError.credentialAccessDenied`, then promotes either result to `ClaudeConnectionFailure.keychainAccessDenied`. A post-wake or early-launch availability failure therefore presents the same recovery as a revoked ACL.
6. Apple documents that **Always Allow** adds the application to the item's trusted-app ACL, `LAContext.interactionNotAllowed` is the supported noninteractive mechanism, and `kSecMatchSearchList` restricts `SecItemCopyMatching` to specified Keychains.

The malformed search list and error collapse are confirmed defects. Whether Claude Code replaces the item's access object during some refreshes remains a hypothesis; Task 4 is the discriminator.

## File Map

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift` — scope the provider lookup to one default/login Keychain and preserve exact `OSStatus` categories.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift` — keep temporary Keychain unavailability separate from authorization-required failure.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift` — degrade noninteractive failure to passive/cache and delete background connection-failure production.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift` — remove connection failure from source presentation.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift` — remove the background credential-failure publisher.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — remove the background monitor-to-connection-state subscription.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift` — remove the background failure mutator and map only explicit Connect/Reconnect results.
- Modify `docs/development/claude-keychain-grant-durability.md` — preserve the new prompt/search-list evidence and final decision.
- Modify `docs/development/authentication-and-usage-collection.md`, `docs/development/operating-notes.md`, and `docs/claude-usage-verification.md` — document retry-later behavior, scoped lookup, and the verified limitation.
- Modify `docs/superpowers/plans/2026-08-29-claude-keychain-statusline-single-binary.md` — link this follow-up and correct any claim that **Always Allow** durability has already been proven.

## Interfaces

### Credential boundary

```swift
enum ClaudeCredentialError: Error, Equatable, Sendable {
    case notFound
    case malformedData
    case interactionNotAllowed
    case accessDenied
    case userCancelled
    case missingEntitlement
    case unexpectedStatus(OSStatus)
}

actor ClaudeKeychainCredentialStore: ClaudeCredentialProviding {
    func loadCredential(
        promptPolicy: KeychainPromptPolicy
    ) async throws -> ClaudeOAuthCredential
}
```

`interactionNotAllowed` remains a separate case all the way to collection. The store returns no account data or diagnostic strings.

### OAuth boundary

```swift
enum ClaudeOAuthError: Error, Equatable, Sendable {
    case credentialsNotFound
    case credentialUnavailable
    case credentialAuthorizationDenied
    case credentialReaderMisconfigured
    case insufficientScope
    case unauthorized
    case malformedResponse
    case serverFailure(statusCode: Int)
    case rateLimited(retryAfter: Date?)
    case transportError
}
```

`credentialUnavailable` is operational and retryable. It can never mutate
connection state. `credentialAuthorizationDenied` is produced only by the
explicit prompt-capable transaction and is the only Keychain result that may
become `.keychainAccessDenied` in connection presentation.

---

### Task 1: Capture a red transition and protect the evidence boundary

**Files:**
- Modify: `docs/development/claude-keychain-grant-durability.md`

**Interfaces:**
- Consumes: current signed app, `securityd` unified logs, attributes-only Keychain metadata.
- Produces: a reproducible, sanitized transition record.

- [ ] **Step 1: Record the sanitized baseline in the durability document.**

Add the observed facts without local paths, team identifiers, account values, or raw logs: same PID reprompted after **Always Allow**; global search list count 168; scoped count one; creation date stable; modification occurred shortly before one prompt; both signed app copies currently pass noninteractive reads.

- [ ] **Step 2: Establish the red-capable command.**

Run the exact installed signed executable, never an unsigned helper:

```bash
/Applications/AgentUsageMonitor.app/Contents/MacOS/CodexUsageMonitor \
  --claude-live-read-once
```

Expected before the fix during the failing transition: passive data is stale,
OAuth is not accepted, and no dialog is displayed. Expected in a healthy state
after Task 2: OAuth is accepted. Use the existing sanitized tier result and
warnings; do not add a second credential read merely for diagnostics.

- [ ] **Step 3: Capture prompt events without secrets.**

```bash
/usr/bin/log show --last 24h --style compact \
  --predicate '(process == "securityd" OR process == "SecurityAgent") AND eventMessage CONTAINS[c] "AgentUsageMonitor"'
```

Record only prompt time, process continuity, and whether **Always Allow** was accepted. Redact local paths and identifiers before adding evidence to the repository.

- [ ] **Step 4: Commit the evidence boundary.**

```bash
git add docs/development/claude-keychain-grant-durability.md
git diff --cached --check
git commit -m "docs: record Claude Keychain reprompt evidence"
```

Expected: a focused documentation commit containing no credential or account data.

### Task 2: Scope the provider-owned lookup to one login Keychain

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift`

**Interfaces:**
- Consumes: `KeychainPromptPolicy`, the user's default Keychain, service `Claude Code-credentials`.
- Produces: one actor-isolated `SecItemCopyMatching` request with `kSecMatchSearchList` containing exactly one `SecKeychain`.

- [ ] **Step 1: Add an exhaustive default-Keychain resolver inside the credential actor.**

The provider item is in the legacy login Keychain, so this narrow compatibility boundary may use deprecated `SecKeychainCopyDefault`; document the reason and report the compiler warning rather than changing build settings or routing to the data-protection Keychain.

```swift
private static func defaultSearchList() throws -> [SecKeychain] {
    var keychain: SecKeychain?
    let status = SecKeychainCopyDefault(&keychain)
    switch status {
    case errSecSuccess:
        guard let keychain else {
            throw ClaudeCredentialError.unexpectedStatus(errSecInternalError)
        }
        return [keychain]
    case errSecInteractionNotAllowed:
        throw ClaudeCredentialError.interactionNotAllowed
    case errSecAuthFailed:
        throw ClaudeCredentialError.accessDenied
    case errSecUserCanceled:
        throw ClaudeCredentialError.userCancelled
    case errSecMissingEntitlement:
        throw ClaudeCredentialError.missingEntitlement
    case errSecItemNotFound:
        throw ClaudeCredentialError.notFound
    default:
        throw ClaudeCredentialError.unexpectedStatus(status)
    }
}
```

- [ ] **Step 2: Make the search scope explicit in the query.**

```swift
static func searchQuery(
    serviceName: String,
    promptPolicy: KeychainPromptPolicy,
    searchList: [SecKeychain]
) -> [String: Any] {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: serviceName,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecMatchSearchList as String: searchList,
    ]
    if promptPolicy == .never {
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
    }
    return query
}
```

Do not add an unrestricted fallback. If the provider item is absent from the default/login Keychain, return `.notFound` and instruct the user to sign in to Claude Code.

- [ ] **Step 3: Preserve all relevant status categories.**

Extend the store's shared `error(for:)` mapping so the
`SecItemCopyMatching` result keeps `errSecInteractionNotAllowed`,
`errSecAuthFailed`, `errSecUserCanceled`, and `errSecMissingEntitlement`
distinct. The default-Keychain resolver and item read use the same typed
categories.

- [ ] **Step 4: Resolve the search list and read inside the actor.**

Call `defaultSearchList()` immediately before `SecItemCopyMatching`, on the existing actor-isolated path. Continue checking the returned `OSStatus` exhaustively and parsing data only after `errSecSuccess`.

- [ ] **Step 5: Verify the query collapses the duplicate machine state.**

Use an attributes-only one-off diagnostic scoped to the default Keychain. It must report one matching item on the affected machine, while the global query continues to report 168 until the user separately approves machine repair. Do not print attributes or persistent references.

- [ ] **Step 6: Compile the production target without tests.**

```bash
swift build --package-path CodexUsageMonitor --product CodexUsageMonitor
```

Expected: exit 0. Record the targeted `SecKeychainCopyDefault` deprecation warning if emitted; do not suppress it globally or change deployment/signing settings.

- [ ] **Step 7: Commit the scoped lookup.**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift
git diff --cached --check
git commit -m "fix: scope Claude credential lookup to login Keychain"
```

### Task 3: Stop temporary unavailability from becoming a reconnect prompt

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift`

**Interfaces:**
- Consumes: exact `ClaudeCredentialError` from Task 2.
- Produces: separate OAuth noninteractive/explicit-authorization errors; only the explicit transaction changes connection state.

- [ ] **Step 1: Classify errors using the prompt policy that produced them.**

```swift
do {
    credential = try await credentialStore.loadCredential(promptPolicy: promptPolicy)
} catch let error as ClaudeCredentialError
    where promptPolicy == .never
        && (error == .interactionNotAllowed || error == .accessDenied) {
    throw ClaudeOAuthError.credentialUnavailable
} catch ClaudeCredentialError.interactionNotAllowed {
    throw ClaudeOAuthError.credentialUnavailable
} catch ClaudeCredentialError.accessDenied {
    throw ClaudeOAuthError.credentialAuthorizationDenied
} catch ClaudeCredentialError.userCancelled {
    throw ClaudeOAuthError.credentialUnavailable
} catch ClaudeCredentialError.missingEntitlement {
    throw ClaudeOAuthError.credentialReaderMisconfigured
} catch ClaudeCredentialError.notFound {
    throw ClaudeOAuthError.credentialsNotFound
} catch {
    throw error
}
```

Do not map `unexpectedStatus` or `missingEntitlement` to
authorization-denied. Preserve the internal typed status; user copy must not
print the raw value.

- [ ] **Step 2: Keep temporary failure operational in the collector.**

```swift
case .credentialUnavailable:
    return "Claude Code’s credential is temporarily unavailable. Showing the last reading and retrying without a prompt."
case .credentialAuthorizationDenied:
    return "macOS denied access to Claude Code’s credential. Reconnect Claude to grant access again."
case .credentialReaderMisconfigured:
    return "Agent Monitor cannot access the macOS Keychain with this build. Showing the last reading."
```

The collector returns the freshest passive snapshot or cache with the warning.
Delete `credentialFailure(for:)`; background collection no longer produces a
`ClaudeConnectionFailure` at all.

- [ ] **Step 3: End the background monitor-to-connection-state coupling.**

Remove the `QuotaViewModel` subscription that forwards
`claudeMonitor.$credentialFailure` into
`ClaudeConnectionController.applyCredentialFailure`. Automatic collection owns
source availability, not enrollment. Only the explicit connection lifecycle or
a successful live OAuth read may change the connection state; a source failure
cannot. Keep a source warning with passive/cache data instead of replacing the
quota card with the reconnect surface.

Delete the now-dead path end to end:

- `ClaudeUsagePresentation.credentialFailure`;
- `ClaudeUsageMonitor.credentialFailure` and its assignments;
- the collector's local `credentialFailure` and mapping helper; and
- `ClaudeConnectionController.applyCredentialFailure`.

Do not replace it with another failure counter, grace timer, wake observer, or
parallel connection-health model.

Update `ClaudeConnectionController.mappedFailure(_:)` for the explicit Connect
path: `.credentialAuthorizationDenied` maps to `.keychainAccessDenied`;
`.credentialUnavailable` and `.credentialReaderMisconfigured` map to
`.usageUnavailable`. No unexpected or configuration status may claim the user
denied permission.

- [ ] **Step 4: Keep ordinary Refresh noninteractive.**

Verify the reason mapping remains exactly:

```swift
case .credentialConnection: .userInitiatedOnly
case .appLaunch, .scheduled, .menuOpened, .userInitiated: .never
```

No retry, wake callback, or ordinary Refresh may substitute `.credentialConnection` merely to improve availability.

- [ ] **Step 5: Let the normal cadence recover.**

Do not add a new wake scheduler or timer. The existing Claude monitor's next cadence and ordinary noninteractive Refresh are sufficient recovery points. A successful OAuth result already calls `applyLiveOAuthSnapshot` and restores connected presentation.

- [ ] **Step 6: Compile the production target without tests.**

```bash
swift build --package-path CodexUsageMonitor --product CodexUsageMonitor
```

Expected: exit 0 with no new errors. Do not run or modify the automated test target.

- [ ] **Step 7: Commit the availability classification.**

```bash
git add \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageSnapshot.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift
git diff --cached --check
git commit -m "fix: retry temporary Claude Keychain failures"
```

### Task 4: Prove whether credential updates preserve the trusted-app ACL

**Files:**
- Modify: `docs/development/claude-keychain-grant-durability.md`

**Interfaces:**
- Consumes: signed Task 2/3 app, one explicit **Always Allow**, sanitized probe, attributes-only creation/modification metadata, unified prompt log.
- Produces: one of four decisions in Step 6, including a stop condition if the provider item is outside the accepted login-Keychain boundary.

- [ ] **Step 1: Use one stable signed app path.**

Install the newly signed build at the normal `/Applications/AgentUsageMonitor.app` path. Quit only the instance started for this acceptance pass; do not terminate a pre-existing user-owned process. Confirm the running path and designated requirement once, then do not rebuild or replace the app during the observation.

- [ ] **Step 2: Establish the grant once.**

Select **Reconnect Claude**, approve **Always Allow**, and immediately run the signed noninteractive probe. Expected: OAuth accepted with no second prompt.

- [ ] **Step 3: Observe an ordinary value update.**

Record only the attributes-only creation and modification timestamps before and after Claude Code renews or updates its credential. Do not force a provider sign-out, delete the credential, or inspect the ACL. Expected invariant: creation is unchanged, modification advances.

- [ ] **Step 4: Re-run the scoped noninteractive read after the update.**

Expected green result: OAuth succeeds and `securityd` records no new prompt. This proves **Always Allow** survived the value update and accepts the scoped-query correction.

- [ ] **Step 5: Exercise extended sleep and relaunch separately.**

After one healthy baseline:

1. Sleep long enough for the passive snapshot and poll deadline to become stale, then unlock normally.
2. Confirm the app continues to show passive/cache data without a reconnect card during any temporary failure.
3. Use ordinary Refresh; confirm it is noninteractive.
4. Quit and relaunch the same installed app path; confirm no prompt.
5. Restart macOS and confirm the first automatic read does not prompt or falsely disconnect Claude.

These are user-owned behavioral checks. Record exact observed states without claiming unrun cases.

- [ ] **Step 6: Apply the decision gate.**

Use this table; do not blend outcomes:

| Observation | Conclusion | Product action |
|---|---|---|
| Scoped read succeeds across modification, sleep, and relaunch | App-side query/state handling caused the false reconnect path | Keep the scoped query and source-only retry behavior |
| Scoped read fails only immediately after wake/restart, then succeeds without interactive Connect | Keychain availability race, ACL intact | Keep retry-later classification; do not prompt |
| Scoped read fails persistently immediately after modification and interactive Connect prompts again for the same signed process | Claude Code changed the access object/ACL despite preserving the item identity | Record borrowed-Keychain durability as provider-controlled; keep OAuth optional and passive/cache primary |
| Scoped read returns not found while global attributes show one real item outside the default Keychain | Provider storage location differs from the accepted login-Keychain contract | Stop; revise ADR before adding a broader fallback |

- [ ] **Step 7: Do not repair a provider-owned ACL.**

If access-object replacement is confirmed, do not call `SecAccess`, `SecACLSetSimpleContents`, `SecItemUpdate`, or shell out to `security` to add Agent Monitor. Such a workaround mutates Claude Code's credential, requires authorization, and violates the accepted provider-ownership boundary.

### Task 5: Reconcile documentation and produce the signed handoff

**Files:**
- Modify: `docs/development/claude-keychain-grant-durability.md`
- Modify: `docs/development/authentication-and-usage-collection.md`
- Modify: `docs/development/operating-notes.md`
- Modify: `docs/claude-usage-verification.md`
- Modify: `docs/superpowers/plans/2026-08-29-claude-keychain-statusline-single-binary.md`
- Modify: `docs/superpowers/plans/2026-09-01-claude-keychain-reprompt-durability.md`

**Interfaces:**
- Consumes: Task 4 decision and production build evidence.
- Produces: durable operating instructions, known limitation, signed `.app`, and a clean branch handoff.

- [ ] **Step 1: Document only the observed decision.**

State whether the accepted fix was search scoping, retry-later classification, or a provider-controlled ACL limitation. Preserve the distinction between “no prompt was observed” and “a case was not run.”

- [ ] **Step 2: Build the main macOS scheme.**

```bash
cd CodexUsageMonitor
xcodebuild -scheme CodexUsageMonitor \
  -destination platform=macOS \
  -derivedDataPath /private/tmp/AgentUsageMonitorDerivedData \
  build
```

Expected: exit 0 and `** BUILD SUCCEEDED **`. Report all warnings precisely.

- [ ] **Step 3: Build and verify the signed app.**

```bash
bash Scripts/build-app.sh
codesign --verify --deep --strict --verbose=4 .build/CodexUsageMonitor.app
find .build/CodexUsageMonitor.app/Contents -type f -perm -111 -print
```

Expected: signed-app build exits 0, strict verification succeeds, and the bundle contains only `Contents/MacOS/CodexUsageMonitor` as an executable file.

- [ ] **Step 4: Run static privacy and prompt-boundary checks.**

```bash
rg -n "kSecReturnData|kSecMatchSearchList|interactionNotAllowed|credentialAuthorizationDenied|credentialUnavailable" \
  Sources/CodexUsageMonitor
rg -n "accessToken|refreshToken|Claude Code-credentials" \
  Sources/CodexUsageMonitor/Quota/ClaudeUsageProbeCommand.swift \
  docs/development/claude-keychain-grant-durability.md
```

Expected: one actor-owned secret read, explicit scoped search, distinct temporary/authorization states, and no token fields or account data in diagnostics.

- [ ] **Step 5: Commit the reconciled handoff.**

```bash
git add \
  docs/development/claude-keychain-grant-durability.md \
  docs/development/authentication-and-usage-collection.md \
  docs/development/operating-notes.md \
  docs/claude-usage-verification.md \
  docs/superpowers/plans/2026-08-29-claude-keychain-statusline-single-binary.md \
  docs/superpowers/plans/2026-09-01-claude-keychain-reprompt-durability.md
git diff --cached --check
git commit -m "docs: record Claude Keychain durability result"
```

- [ ] **Step 6: Leave behavioral acceptance with the user.**

Do not mark **Always Allow** durable until the user completes the signed-app modification, sleep, relaunch, and restart sequence. Do not add or run automated test cases.

## Completion Criteria

- [ ] The credential query searches exactly one default/login Keychain even when the global search list contains duplicate entries.
- [ ] Automatic and ordinary Refresh reads remain structurally noninteractive.
- [ ] A noninteractive Keychain failure preserves connection state, serves passive/cache data, and recovers on a later noninteractive read.
- [ ] Only a denial observed during explicit Connect/Reconnect changes the connection state.
- [ ] One **Always Allow** grant survives a value-only Claude credential update for the same signed installed app, or the provider's access-object replacement is captured and documented as the limiting cause.
- [ ] No code edits, deletes, exports, or attempts to repair Claude Code's credential or ACL.
- [ ] Production scheme and signed-app builds exit 0; the app bundle contains one executable.
- [ ] Automated tests remain untouched and unrun; signed behavior acceptance is reported only from the user's observation.

## Explicit Non-Goals

- Creating or storing an app-owned Claude token.
- Reviving `claude setup-token` or browser callback OAuth.
- Editing Claude Code's Keychain item or trusted-application ACL.
- Repairing or normalizing the user's global Keychain search list.
- Silently prompting after wake, launch, scheduled refresh, or ordinary Refresh.
- Treating a provider-owned legacy Keychain lookup as a reason to migrate the credential into Agent Monitor's data-protection Keychain.
- Guaranteeing live OAuth data while the provider credential is unavailable; passive/cache data remains the safe degradation.

## Reference Files

- `swift-security-expert/SKILL.md` — exhaustive `OSStatus`, actor isolation, and retry-later security invariants.
- `swift-security-expert/references/keychain-fundamentals.md` — `SecItemCopyMatching`, search scoping, legacy/data-protection routing, and `errSecInteractionNotAllowed` handling.
- `docs/adr/0002-claude-usage-auth-and-bridge-boundaries.md` — provider-owned credential and noninteractive read boundary.
- `docs/development/claude-keychain-grant-durability.md` — prior and current machine evidence.
- Apple [`Access Control Lists`](https://developer.apple.com/documentation/security/access-control-lists) — **Always Allow** trusted-application semantics.
- Apple [`kSecMatchSearchList`](https://developer.apple.com/documentation/security/ksecmatchsearchlist) — explicit Keychain query scope.
- Apple [`LAContext.interactionNotAllowed`](https://developer.apple.com/documentation/localauthentication/lacontext/interactionnotallowed) — supported noninteractive authentication behavior.
