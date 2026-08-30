# Claude single-binary branch review and simplification options

- Reviewed branch: `feat/claude-setup-token-primary`
- Fixed point: `origin/main` at `b77aca53e4430b44b5dd2d5216ed79506ec87f19`
- Reviewed head: `51b0a2c8681e7b1dec1e5f48cd71cd6f881bd4e9`
- Diff: `git diff origin/main...HEAD`
- Active specification: `docs/superpowers/plans/2026-08-29-claude-keychain-statusline-single-binary.md`
- Durable decision: `docs/adr/0002-claude-usage-auth-and-bridge-boundaries.md`

This is a static code and documentation review. No production code was changed,
and no automated or behavioral tests were run. The review separates repository
standards from specification fidelity, then turns the over-engineering findings
into concrete edit options.

## Outcome

The accepted design is sound: passive status-line data first, a borrowed Claude
Code Keychain credential for authoritative usage, manual `/usage`, and one signed
Mach-O. The branch should not be proposed for merge yet. The most important issue
is not the amount of code; it is that `ClaudeStatusLineInstaller` performs writes
inside a failable initializer. That makes read-only inspection mutate the
filesystem and makes Disconnect cleanup conditional on successfully creating or
validating a new bridge first.

The best cleanup sequence is:

1. Make status-line construction read-only and make cleanup non-failable.
2. Correct the credential-scope and connection-proof semantics.
3. Remove dead sign-in presentation code and duplicate state mapping.
4. Remove obsolete test code or update only defect-regression coverage in a
   separately authorized test-maintenance pass.
5. Correct the public documentation, labels, typography, and private paths.

## Implementation status

The accepted revisions have been applied in focused commits after this review:

- `e25a890` makes `ClaudeStatusLineInstaller` construction read-only and makes
  managed-capture cleanup independent of bridge-link preparation.
- `66bdbbd` simplifies connection proof and controller state, shares the OAuth
  source, removes unused credential fields, and reduces the executable locator.
- `8763db4` removes the unused sign-in presentation and view, centralizes the
  remaining connection copy, and reconciles recovery typography and action labels.

The final reconciliation removes stale test suites and updates durable
documentation without adding, rewriting, compiling, or running tests. This is a
deliberate no-test/no-visual boundary: behavioral and visual acceptance remain
user-owned rather than implied by these static changes.

## Standards

### Hard violations

1. `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeCompositeCredentialStoreTests.swift:4`
   still depends on deleted setup-token and composite-store production types.
   `ClaudeUsageCollectorTests.swift:272` also adds feature-presence coverage even
   though `AGENTS.md` and the active plan prohibit authoring or maintaining tests
   in this implementation. The test target cannot compile as committed, while
   the plan says no tests were authored. This conflicts with `AGENTS.md`,
   `CONTRIBUTING.md`, and the plan's stated verification boundary.

2. `docs/superpowers/plans/2026-08-26-claude-setup-token-primary-and-recovery.md:658`
   commits four user-home absolute paths. The public-update workflow explicitly
   prohibits user-specific paths.

3. `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift:17`
   renders permission and recovery guidance with `.caption`. `AGENTS.md` requires
   permission, failure, and recovery text to be at least callout-sized.

4. `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift:97`
   maps `.insufficientScope` to `.credentialsNotFound`, producing a false
   recovery message. The active plan requires a distinct message that the current
   credential cannot read usage and Claude Code must be signed in again.

5. `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift:80`
   and `ClaudeAgentSettingsView.swift:226` use **Repair**, **Set Up**, and
   **Connect** instead of the required **Repair Passive Capture**,
   **Set Up Passive Capture**, and **Connect Claude** labels.

6. `CodexUsageMonitor/Sources/CodexUsageMonitor/AgentUsageMonitorEntryPoint.swift:6`
   says the executable is copied to Application Support. The implementation and
   ADR use a symlink because copying the executable was rejected.

7. The active plan leaves the repeated power gate unchecked while later claiming
   the bridge met its measured acceptance gate. This conflicts with
   `CONTRIBUTING.md`'s rule to distinguish observed evidence from inference.

### Judgment calls

1. `ClaudeSignInPresentation.swift`, `ClaudeConnectionStatus.swift`,
   `ClaudeCredentialActions.swift`, and `ClaudeUnavailableContent.swift` repeat
   switches over `ClaudeConnectionState`. This is a repeated-switch smell, not a
   hard violation.

2. `ClaudeConnectionController.reportFailure`, `ClaudeSignInView`, and most of
   `ClaudeSignInPresentation.make` have no production caller. These are unused or
   speculative surfaces.

3. `QuotaViewModel.swift:120` and `QuotaViewModel.swift:141` construct equivalent
   `ClaudeOAuthUsageSource` values instead of sharing one configured source.

## Spec

1. **Passive inspection mutates state.** The plan says a project-owned command
   may be repaired automatically only after durable management consent and that
   onboarding appearance must not install or read anything. Settings calls
   `refreshClaudePassiveCaptureHealth()` from `.onAppear`; constructing
   `ClaudeStatusLineInstaller` immediately creates, validates, and atomically
   replaces the bridge symlink. Inspection therefore writes even without current
   enrollment or managed-capture consent.

2. **Disconnect cleanup depends on creating the bridge first.** The ADR requires
   Disconnect to remove the exact managed status-line entry, symlink, snapshot,
   and cache. `disconnectClaude()` calls the failable, mutating initializer before
   `uninstallManagedCapture()`. A missing executable, invalid signature, or link
   preparation error skips cleanup. The uninstall method also returns before
   deleting the link and snapshot when settings are unreadable or repairable.

3. **Insufficient scope has the wrong recovery.** The implementation reports that
   no credential exists even though the credential was successfully read and its
   scope was inspected.

4. **Connect disclosure and labels do not express the one-action contract.** The
   plan requires both Keychain access and passive-capture enrollment to be
   disclosed before one consistently named **Connect Claude** action. Some
   surfaces put credential-only disclosure after a generically named button.

5. **Durable documentation describes the removed helper.** `README.md:414` still
   describes `ClaudeUsageBridge` as a separate bundled executable and future
   consolidation work. The entry-point comment also says “copied,” not “linked.”

No material scope creep was found. The worst Standards issue is a non-compiling,
contradictory test boundary; the worst Spec issue is the mutating installer and
cleanup lifecycle. Totals: Standards 10 findings (7 hard, 3 judgment calls);
Spec 5 findings.

## Simplification edit notes

### 1. Make `ClaudeStatusLineInstaller` a read-only value

**Locations:**
`Settings/ClaudeStatusLineInstaller.swift:92-183`,
`Menu/QuotaViewModel.swift:85-90,401-418,427-434`

**Tag:** `shrink`

**Reason:** A constructor that validates signatures, creates directories, creates
a staging link, and renames it into place hides a write transaction behind object
creation. Every caller must then treat ordinary inspection and cleanup as
optional. It duplicates lifecycle policy across the initializer, `install`, the
view model's launch path, and `uninstallManagedCapture`.

**Recommended revision:**

- Make initialization non-failable and side-effect free. It should only derive
  `settingsURL`, `sourceExecutable`, `bridgeExecutable`, and `bridgeCommand`.
- Move `prepareBridgeLink` into `install(replacingExisting:)` after the existing
  status-line/consent decision.
- Add an explicit `repairManagedLinkIfNeeded()` used only at launch when both
  Claude enrollment and the durable managed-capture flag are true.
- Make `inspect()` read only settings and filesystem state; it must not create a
  link or validate the app signature.
- Make `uninstallManagedCapture()` independently attempt the exact settings-entry
  removal, symlink removal, snapshot removal, and managed-flag removal. Failure to
  parse settings should preserve that file but must not prevent app-owned file
  cleanup.

**Smaller alternative:** Keep `prepareBridgeLink` unchanged, but call it only from
`install` and the consent-gated launch repair. Add a separate non-failable cleanup
function that derives the stable paths without constructing the installer.

**Expected effect:** simpler call sites, no hidden writes, a reliable Disconnect,
and roughly 15-25 fewer lines of optional-guard and repeated-read control flow.

### 2. Use one source-aware definition of “connected”

**Locations:**
`Connection/ClaudeConnectionStatus.swift:20-68`,
`Settings/ClaudeAgentSettingsView.swift:190-260`,
`Quota/ClaudeUsageMonitor.swift:158-165`

**Tag:** `shrink`

**Reason:** `delivery == .live` currently treats a manual CLI `/usage` result as
proof that the borrowed Keychain credential works. It is not. The resolver then
needs a second `isEffectivelyConnected` method to compensate for explicit
connection state, and Settings adds two more Boolean derivations.

**Recommended revision:** Define credential proof once:

```swift
let hasLiveOAuth = usageState.presentation.map {
    $0.delivery == .live && $0.snapshot.source == .oauth
} ?? false
let isConnected = signInState.isConnected || hasLiveOAuth
```

Use the resolved status for both the status row and Connect/Disconnect action.
Delete `isEffectivelyConnected` and make `showsConnectAction` a property of the
resolved status or a single direct Boolean. Keep passive status-line and manual
CLI readings visible as usage, but do not call them credential proof.

**Alternative:** Make `ClaudeConnectionController` the sole authority and feed it
only successful OAuth refresh outcomes. This is cleaner semantically but widens
the collector-to-controller interface, so it is not the minimal edit.

**Expected effect:** fixes a misleading state and removes about 10-15 lines of
compensating status logic.

### 3. Delete the unused sign-in view and reduce the presentation type to copy

**Locations:**
`Menu/ClaudeSignInView.swift:3-38`,
`Menu/ClaudeSignInPresentation.swift:3-46`

**Tags:** `delete`, `yagni`

**Reason:** `ClaudeSignInView` has no production caller. Consequently,
`ClaudeSignInPresentation.make`, its four stored properties, and its state
mapping exist only for the dead view and stale tests. The only live values are
the two disclosure strings used by menu and Settings surfaces.

**Recommended revision:** Delete `ClaudeSignInView.swift`. Replace
`ClaudeSignInPresentation` with a small copy namespace such as
`ClaudeConnectionCopy` containing only `keychainDisclosure` and
`keychainPromptExplanation`. Expand the disclosure so it names both Keychain
access and passive-capture enrollment before the action.

**Alternative:** If a standalone sign-in view is planned for an identified
surface, wire it now and make it the shared owner of that surface. Do not retain
an unwired view as future flexibility.

**Expected effect:** approximately 65-75 production lines removed.

### 4. Collapse one-caller connection machinery

**Location:**
`Connection/ClaudeConnectionController.swift:29-76`

**Tags:** `delete`, `yagni`, `shrink`

**Reason:** After removing the two-method setup-token design, `beginSignIn` has
one caller and its `operation` parameter is always `credentialsSignIn`.
`reportFailure` has no caller. Those seams preserve flexibility that the accepted
one-action design explicitly removed.

**Recommended revision:** Inline the body of `beginSignIn` into `connect()` and
call `credentialsSignIn` directly. Delete `reportFailure`. Keep the task,
cancellation check, and attempt ID: they prevent a cancelled Disconnect-era task
from publishing a late success.

**Alternative:** Keep `beginSignIn` only if a second concrete connection action is
approved; delete `reportFailure` either way.

**Expected effect:** roughly 8-12 lines removed without weakening cancellation.

### 5. Share the OAuth source and discard unused secret fields

**Locations:**
`Menu/QuotaViewModel.swift:120-154`,
`Connection/ClaudeOAuthCredential.swift:8-14,112-134`

**Tags:** `shrink`, `delete`

**Reason:** The view model constructs the same OAuth source twice. The credential
also decodes and retains `refreshToken` and `expiresAt`, but production never reads
either field and the ADR prohibits this app from refreshing Claude Code's token.
Keeping unused secret material increases surface area without providing behavior.

**Recommended revision:** Construct one `ClaudeOAuthUsageSource` local and pass it
to both the collector and the user-initiated connection closure. Remove
`refreshToken` and `expiresAt` from `ClaudeOAuthCredential` and its decoding
wrapper; `Decodable` safely ignores those provider JSON keys. Preserve
`accessToken`, `scopes`, and `subscriptionType`.

**Alternative:** If expiry will be displayed or used in an approved capability
gate, retain `expiresAt` but still remove `refreshToken`; direct refresh remains a
non-goal.

**Expected effect:** about 8-10 lines removed and a smaller in-memory secret
boundary.

### 6. Return an optional from the executable locator

**Location:**
`Connection/ClaudeExecutableLocator.swift:3-42`

**Tag:** `shrink`

**Reason:** Every production caller immediately converts `locate()`'s only error
to `nil` with `try?`, then maps absence to its own domain error. The dedicated
throwing error type carries no information across the boundary.

**Recommended revision:** Change `locate()` to return `URL?`, delete
`ClaudeExecutableLocatorError`, and return the first executable candidate mapped
to a URL. Keep the explicit override, official installer path, Homebrew paths,
and GUI-safe PATH scan.

**Alternative:** Keep the throwing API only if callers will expose distinct
locator failure details. No current caller does.

**Expected effect:** roughly 5 lines removed and simpler call sites.

### 7. Remove no-op and duplicated migration work

**Locations:**
`Menu/QuotaViewModel.swift:91-95,156,434`,
`Connection/ClaudeLegacySetupTokenCleanup.swift:7-38`

**Tag:** `delete`

**Reason:** Reading `claude.credential-method.v1` immediately before deleting it
has no effect. The one-way legacy Keychain deletion is also launched at startup
and again on every Disconnect even though the retired production route cannot
recreate the item.

**Recommended revision:** Delete the no-op `string(forKey:)` read. Run the exact
legacy cleanup once during versioned migration/startup, retaining its actor,
specific service/account query, data-protection-keychain routing, and exhaustive
`OSStatus` classification.

**Alternative:** If retry-after-lock is required, persist a non-secret migration
completion flag and retry only while incomplete rather than on every Disconnect.

**Expected effect:** a small line reduction, but more importantly one explicit
migration lifecycle instead of incidental cleanup attached to account actions.

### 8. Read and classify Claude settings once per operation

**Location:**
`Settings/ClaudeStatusLineInstaller.swift:209-324`

**Tag:** `shrink`

**Reason:** `install` reads and parses settings into `root`, then calls `inspect`,
which reads and parses the same file again. `uninstallManagedCapture` follows the
same inspect-then-read pattern. The duplicate reads create more guards and allow
the classification and mutation inputs to disagree if the file changes between
them.

**Recommended revision:** Add one small `loadSettings()` result containing the
parsed root and current status-line command. Let `inspect`, `install`, and
`uninstall` classify that already-loaded value. Do not introduce a repository or
protocol; a private helper/result enum in the same file is enough.

**Alternative:** Keep `inspect()` public but add a private overload that accepts
the parsed root, so mutating operations reuse their first read.

**Expected effect:** about 10-15 lines removed and fewer inconsistent branches.

## Required corrections that are not optional simplifications

These edits are merge hygiene or behavior fixes rather than ponytail cuts:

- Add a distinct insufficient-scope connection failure and the required factual
  recovery message.
- Make the combined Connect disclosure visible before the action, use the
  specified labels, and render recovery guidance at callout size.
- Replace the README's separate-helper architecture description with the current
  main-executable bridge mode and stable symlink.
- Change the entry-point comment from “copied” to “linked.”
- Replace the four user-specific absolute skill paths with repository-neutral
  reference names or remove them.
- Reconcile the test target in a separately authorized maintenance pass. The
  smallest option is to delete obsolete setup-token/composite-store tests and
  retain only deterministic defect regressions that still describe production.
  Do not disable the whole test target to hide compile failures.
- Correct the plan's power-evidence claim or complete the unchecked repeated-run
  gate before asserting it passed.

## Security boundaries not to simplify away

The complexity review deliberately does **not** recommend these cuts:

- Keep `ClaudeKeychainCredentialStore` actor-isolated; `SecItemCopyMatching` must
  not run on `@MainActor`.
- Keep automatic Keychain reads non-interactive with `LAContext` and preserve the
  explicit prompt policy.
- Keep the legacy deletion query restricted to the exact app-owned service and
  account, and continue checking every `OSStatus`.
- Keep the provider-owned Claude Code lookup compatible with the login Keychain,
  as explicitly decided in ADR 0002; do not force data-protection routing onto a
  provider-owned item.
- Keep atomic replacement of the stable symlink and strict code-signature
  validation. These defend an observed packaging boundary, not a hypothetical
  one.
- Keep the connection attempt ID and cancellation checks unless an equivalent
  stale-task guard replaces them.
- Keep the GUI-safe Claude executable search paths. A menu-bar app cannot assume
  an interactive shell's PATH.

## Ponytail summary

`ClaudeSignInView.swift:L3-38: delete: unwired sign-in view. Nothing replaces it.`

`ClaudeSignInPresentation.swift:L3-46: yagni: state model used only by the dead view. Keep two shared disclosure strings in a copy namespace.`

`ClaudeConnectionController.swift:L43-72: yagni: generic one-caller sign-in helper. Inline it into connect().`

`ClaudeConnectionController.swift:L74-76: delete: unused reportFailure hook. Nothing replaces it.`

`QuotaViewModel.swift:L120-154: shrink: two equivalent OAuth source constructions. Construct once and share it.`

`ClaudeOAuthCredential.swift:L10-11: delete: unused refresh token and expiry retained despite a no-direct-refresh policy. Decode only used fields.`

`ClaudeExecutableLocator.swift:L3-42: shrink: one thrown error every caller discards. Return URL?.`

`ClaudeStatusLineInstaller.swift:L108-183: shrink: failable side-effecting initializer spreads guards and lifecycle policy. Use a pure initializer and explicit install/repair methods.`

`ClaudeStatusLineInstaller.swift:L251-324: shrink: install and uninstall parse settings twice. Load and classify once per operation.`

`QuotaViewModel.swift:L94: delete: UserDefaults read immediately discarded before removal. Nothing replaces it.`

Conservative production estimate, excluding obsolete tests and documentation:
`net: -100 lines possible.`
