# Claude Usage Provider Wiring (Live Monitor + Gated Settings Surface) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the already-built-but-unwired Claude backend into the app's first *real* (non-preview) Claude read: make `ClaudeUsageMonitor` own and drive `ClaudeUsageCollector` (OAuth → statusLine → cache) on a network-appropriate cadence, and replace the static `ClaudeCodePreviewSettingsView` with a real read-only status view driven by that monitor. This is the increment that satisfies the two remaining [capability-gate](2026-07-20-claude-code-capability-research.md#gate-before-implementation) criteria — **#3 (product copy correctly scopes what the number means)** and **#5 (explicit "not available" fallback, never a best-effort estimate presented as a quota)** — so Claude Code stops being a static preview. The menu-bar Claude card and the tier-3 CLI `/usage` PTY probe stay deferred to their own plans.

## Where this sits (state as of 2026-07-21)

Everything in `claude_probe_plan` tiers 1–2 and the four-tier coordinator (minus tier 3) is **already built, merged (PR #23), and green** — 44 Claude Swift tests + 13 Python tests pass. But **none of it is reachable by a user**: the only Claude code wired into the running app is the static `ClaudeCodePreviewSettingsView` (see [AgentsSettingsView.swift:24](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift#L24)).

Two concrete gaps this plan closes, beyond "no UI":

1. **The single-owner claim is not actually true yet.** `ClaudeUsageMonitor` polls `ClaudeRateLimitSnapshotReader` *directly* every 30s and publishes `ClaudeUsageState` (`.available(ClaudeRateLimitSnapshot)`), completely bypassing `ClaudeUsageCollector` — so the primary source (OAuth) never runs in the app, and there are **two parallel, unconnected representations** (`ClaudeRateLimitSnapshot` vs `ClaudeUsagePresentation`). The monitor-owner plan predates the provider/collector plan and was never reconciled with it. Gate criterion #4 ("a single owner … with no second polling source") is only genuinely met once the monitor drives the collector.
2. **The Keychain credential read has no prompt policy.** `ClaudeKeychainCredentialStore.loadCredential()` issues a bare `SecItemCopyMatching` against Claude Code's item ([ClaudeOAuthCredential.swift:50](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L50)). Reading *another* app's Keychain item can raise an ACL prompt; `claude_probe_plan` §4 requires background/menu-open reads to **never** prompt and only user-initiated reads to allow one. Going live without this risks a Keychain dialog interrupting a background refresh — the exact failure the probe plan forbids.

## Architecture

- `ClaudeUsageMonitor` (existing `@MainActor ObservableObject`) is **rebuilt** to own a `ClaudeUsageCollector` instead of a raw `ClaudeRateLimitSnapshotReader`. It publishes a new `ClaudeUsagePresentation`-based display state (or `nil` for the explicit not-available case). Its refresh cadence changes from a fixed 30s file poll to a **network-appropriate** schedule matching `claude_probe_plan` §8: OAuth-eligible refresh every 10–15 min, plus app-launch, menu-open, and user-initiated triggers. The collector's own decision algorithm handles the cheap statusLine/cache fallback within each refresh — the monitor no longer file-polls independently.
- `ClaudeKeychainCredentialStore` gains a `KeychainPromptPolicy` (`.never` / `.userInitiatedOnly`), threaded from `ClaudeRefreshReason`, so background and menu-open reads pass `kSecUseAuthenticationUI` = *fail* (never prompt) and only `.userInitiated` reads allow interaction. A denied/unavailable read falls through to statusLine, never a hard failure (probe plan §4, §11).
- A new read-only SwiftUI view, `ClaudeUsageStatusView`, replaces `ClaudeCodePreviewSettingsView` in `AgentsSettingsView`. It renders the reconciled monitor's published state: five-hour + weekly windows with source label and relative capture time when data exists, and an explicit unavailable/onboarding state otherwise. Product copy carries the shared-pool caveat (probe plan §9, gate #3).
- `QuotaViewModel` gains ownership of the `ClaudeUsageMonitor` (mirroring how it owns Codex's `QuotaMonitor`/`CodexConnectionController`), started/stopped on the same app-launch/menu lifecycle, and exposes its state to `AgentsSettingsView`.
- `ClaudeUsageBridge/` is bundled as an app resource so `ClaudeStatusLineInstaller.bridgeDirectory`'s production path resolves (currently unresolvable — the script isn't in the signed `.app`).

**Tech Stack:** Swift 6.2, Foundation, `Security` (Keychain), Combine (`ObservableObject`), SwiftUI, XCTest — no new dependencies. Reuses the existing, tested `ClaudeUsageCollector`, `ClaudeOAuthUsageSource`, `ClaudeUsageCache`, and `ClaudeRateLimitSnapshotReader` unchanged where possible.

## Global constraints

- **Do not weaken any privacy/security boundary** from `claude_probe_plan` §11 or the [capability research](2026-07-20-claude-code-capability-research.md#privacy-and-product-boundary): no token persisted outside Keychain, no token logged or in error reports, no conversation content read, no `.credentials.json`/`settings.json` *contents* read beyond what `ClaudeStatusLineInstaller` already does for the `statusLine` key.
- **Never present stale/expired as live.** When a window's `resetsAt` has passed, or delivery is `.cached`, the UI must say so (probe plan §7, §9; gate #5).
- **Background refresh must never open a network dialog, a Keychain prompt, or the CLI.** Only `.userInitiated` may prompt Keychain. The CLI probe (tier 3) is out of scope entirely.
- **TDD throughout.** Every task writes failing tests first, and each ends by running the full Swift suite to confirm zero regressions against the 44-test Claude baseline.
- Match existing Codex presentation conventions (`CodexAgentSettingsView`, `SettingsSection`/`SettingsSectionRow`) so the Claude page reads as part of the same Settings system.

---

## Task 1: Add a Keychain prompt policy to the credential store

**Why first:** wiring OAuth live without this can pop a Keychain dialog during a background/menu-open refresh — the precise interruption `claude_probe_plan` §4 forbids. This is a prerequisite for making OAuth reachable in the running app.

- [ ] **Step 1: Write the failing tests** in `ClaudeKeychainCredentialStoreTests.swift`
  - `testUserInitiatedPolicyAllowsInteraction` — with `.userInitiatedOnly`, the query built for `SecItemCopyMatching` does **not** set `kSecUseAuthenticationUI` to fail.
  - `testBackgroundPolicyNeverPrompts` — with `.never`, the query sets `kSecUseAuthenticationUI` = `kSecUseAuthenticationUIFail` (or the current-SDK equivalent).
  - `testInteractionNotAllowedFallsThroughAsAccessDenied` — when the raw reader returns the "interaction required" status under `.never`, `loadCredential` throws `.accessDenied` (so the collector falls through to statusLine, never blocks).
  - Keep the existing injected-`rawDataReader` tests green; the policy is passed *into* the reader closure.
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement.** Add `enum KeychainPromptPolicy { case never; case userInitiatedOnly }`. Change `ClaudeCredentialProviding.loadCredential()` to `loadCredential(promptPolicy:)`. In `readKeychainData`, set `kSecUseAuthenticationUI` from the policy. Default call sites to `.never`. Update the injected initializer to receive the policy so tests can assert on it.
- [ ] **Step 4: Run the tests to verify they pass.**
- [ ] **Step 5: Thread the policy through `ClaudeOAuthUsageSource.fetch()`** — add a `promptPolicy` parameter (default `.never`) and pass it to `credentialStore.loadCredential(promptPolicy:)`. Update `ClaudeOAuthUsageSourceTests` fakes accordingly.
- [ ] **Step 6: Commit.**

## Task 2: Reconcile `ClaudeUsageMonitor` to own and drive `ClaudeUsageCollector`

**This is the core reconciliation.** After this, the monitor drives the full OAuth → statusLine → cache hierarchy through one owner, and `ClaudeUsageState` carries a `ClaudeUsagePresentation`.

- [ ] **Step 1: Write the failing tests** in `ClaudeUsageMonitorTests.swift` (using a fake collector injected into the monitor)
  - `testRefreshPublishesLivePresentationFromCollector` — collector returns `.live` OAuth snapshot → monitor state exposes it with `delivery == .live`.
  - `testRefreshFallsBackToPassiveAndCached` — collector returns `.passiveSnapshot` / `.cached` → monitor reflects the delivery faithfully (source preserved separately from delivery).
  - `testNoUsableSourcePublishesNotAvailable` — collector returns the empty/no-source presentation → monitor state is the explicit not-available case (not a zeroed snapshot).
  - `testUserInitiatedRefreshUsesUserInitiatedReason` and `testBackgroundRefreshUsesBackgroundReason` — the monitor passes the correct `ClaudeRefreshReason` (which gates Keychain prompt policy) for each trigger.
  - `testStopCancelsPolling` — carried over from the existing suite, now against the collector-driven task.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
  - Change `ClaudeUsageMonitor` to hold a `ClaudeUsageCollector` (injected; default constructs one from `ClaudeOAuthUsageSource(ClaudeKeychainCredentialStore())`, `ClaudeRateLimitSnapshotReader()`, `ClaudeUsageCache()`).
  - Replace `ClaudeUsageState` with: `enum ClaudeUsageState { case unavailable(reason: String); case available(ClaudeUsagePresentation) }` (or `Optional<ClaudeUsagePresentation>` + a reason). Update `ClaudeUsageSnapshotTests`/existing state assertions.
  - `refreshNow(reason:)` calls `await collector.refresh(reason:)` and maps the result to the state; the "no usable source" presentation (empty snapshot + warning) maps to `.unavailable`.
  - Change the cadence: default `pollInterval` to **12 minutes** (OAuth-eligible), with `refresh(reason: .scheduled)` on the timer, `refresh(reason: .menuOpened)` / `.appLaunch` on lifecycle, and `refresh(reason: .userInitiated)` for manual. Remove the 30s local-file poll.
  - Map `ClaudeRefreshReason` → `KeychainPromptPolicy` (only `.userInitiated` → `.userInitiatedOnly`, everything else → `.never`) and pass it down through the collector/OAuth source. This requires `ClaudeUsageCollector.refresh` to forward the prompt policy to `oauthSource.fetch(promptPolicy:)` — add that thread-through and update `ClaudeUsageCollectorTests`.
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Run the full Swift suite** (`swift test --filter Claude`) to confirm no regressions.
- [ ] **Step 6: Commit.**

## Task 3: Add UI presentation mapping (freshness + scoping copy) — gate criterion #3

- [ ] **Step 1: Write failing tests** for a pure `ClaudeUsageDisplayModel` mapper (new `ClaudeUsageDisplayModelTests.swift`)
  - Relative capture time strings ("just now", "8 minutes ago", "3 hours ago") from `capturedAt`.
  - Delivery-specific source labels: `.live`+`.oauth` → "Claude OAuth"; `.passiveSnapshot`+`.statusLine` → "Claude Code capture"; `.cached` → "Cached … result" preserving `source` (probe plan §9 "Source labels").
  - Expired-window detection: a window whose `resetsAt` is in the past renders an explicit "window has since reset" note, never the raw percentage as current (probe plan §7).
  - Shared-pool caveat present in the weekly-window copy (gate #3) — a constant string the view shows; assert it's carried.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** `ClaudeUsageDisplayModel` as a pure struct built from `ClaudeUsagePresentation`. No view logic — just formatted strings + booleans the view binds to.
- [ ] **Step 4: Run to verify they pass. Commit.**

## Task 4: Build `ClaudeUsageStatusView` and replace the static preview — gate criterion #5

- [ ] **Step 1: Implement `ClaudeUsageStatusView`** driven by a `ClaudeUsageDisplayModel?` (nil / `.unavailable` → the explicit unavailable state). Use `SettingsSection`/`SettingsSectionRow`/`SettingsLabeledRow` to match `CodexAgentSettingsView`. States, per probe plan §9:
  - **Available:** plan hint, five-hour row (`used%` + reset), weekly row (`used%` + reset + shared-pool caveat), source label + relative capture time. Cached/stale delivery shows the "live usage temporarily unavailable" line; expired windows show the reset note.
  - **Unavailable:** "Claude usage unavailable — sign in through Claude Code, or enable passive capture." plus a manual-refresh affordance. No zeros, no invented numbers (gate #5).
- [ ] **Step 2: Swap** `ClaudeCodePreviewSettingsView()` for `ClaudeUsageStatusView(...)` in [AgentsSettingsView.swift:24](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift#L24). Keep `ClaudeCodePreviewSettingsView` file for now only if referenced elsewhere; otherwise delete it.
- [ ] **Step 3:** SwiftUI views aren't unit-tested here; rely on the Task 3 mapper tests. Add a lightweight `@MainActor` snapshot-of-state test if the view is refactored to expose a testable body input. **Commit.**

## Task 5: Own `ClaudeUsageMonitor` in `QuotaViewModel` and wire lifecycle

- [ ] **Step 1: Write failing tests** (`QuotaViewModel` Claude ownership): the view model constructs a `ClaudeUsageMonitor`, exposes its published state, calls `start()` on app launch and `refresh(reason: .menuOpened)` when the menu opens (mirror the existing Codex menu-open hook), and `stop()`s on teardown.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Add a `ClaudeUsageMonitor` property to `QuotaViewModel` (injectable for tests), subscribe its `@Published` state, expose a `claudeDisplayModel` computed from it, and pass it into `AgentsSettingsView` → `ClaudeUsageStatusView`. Hook `start()`/menu-open/`stop()` into the same places Codex uses. Guard behind the existing `--live-read-once` short-circuit.
- [ ] **Step 4: Run the full suite. Commit.**

## Task 6: Bundle `ClaudeUsageBridge/` so the installer's production path resolves

- [ ] **Step 1: Write a failing test** asserting `ClaudeStatusLineInstaller.bridgeDirectory` resolves to an existing bundled resource path in a test build (or a documented, deterministic Application Support install path the installer copies to on first run).
- [ ] **Step 2: Implement.** Add `ClaudeUsageBridge/` as a package/app resource (SwiftPM `resources:` copy or an Xcode "Copy Files" phase), and have `ClaudeStatusLineInstaller` resolve `bridgeDirectory` from `Bundle.module`/`Bundle.main`, copying into `~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/` if the app-bundle path is read-only. Do **not** yet surface a one-click "Set up passive capture" button — that's the menu/onboarding follow-up; this task only makes the path *reachable*.
- [ ] **Step 3: Run to verify it passes. Commit.**

## Task 7: Documentation and bookkeeping

- [ ] **Step 1: Update the [capability research gate](2026-07-20-claude-code-capability-research.md#gate-before-implementation)** — mark criteria #3 and #5 satisfied by this plan (with the same "Implementation note" style used for #1 and #4), and note that Claude is no longer a static preview.
- [ ] **Step 2: Update [the planning board](../../product/planning-board.md)** — move the Claude provider row from **Deferred** toward **In progress / Shipped (gated)** as appropriate, linking this plan; note the still-deferred menu card and tier-3 CLI.
- [ ] **Step 3: Check the boxes** on the three 2026-07-20 Claude plans (their code is merged but their checkboxes were never ticked), so the plan record matches reality.
- [ ] **Step 4: Commit.**

---

## Explicitly deferred (own future plans, not dropped)

- **Menu-bar Claude card** — a Claude quota card in `MenuBarExtra`/`QuotaMenuView` alongside Codex, with a "Refresh Claude Usage" action. This plan surfaces Claude only in Settings; the menu card is `claude_probe_plan` Task 9's remainder.
- **Tier 3 — user-authorized CLI `/usage` PTY probe** (`claude_probe_plan` §6 / Task 7). Highest risk surface; its own plan.
- **One-click `statusLine` setup + conflict-merge UX** (`claude_probe_plan` §5 "Claude configuration integration") — Task 6 here only makes the bridge path resolvable; the interactive installer UI is deferred.
- **Account-change fingerprinting / quarantine** (`claude_probe_plan` §5 "Account-change protection") — the current snapshot model has no `credentialFingerprint`; add when multi-account handling is in scope.
- **OAuth token refresh** (`claude_probe_plan` §4 "Credential refresh") — for now an expired access token surfaces as "unavailable, sign in through Claude Code," per the probe plan's own fallback allowance.
- **Real-account parity verification** (`claude_probe_plan` Task 11) — run once the live surface exists.

## Completion criteria

- The Claude Settings page shows a real read from the reconciled monitor (OAuth when available, statusLine/cache fallback), never the static preview.
- Background and menu-open refreshes never raise a Keychain prompt; only user-initiated may.
- A denied Keychain read or failed OAuth falls through to statusLine/cache, then to an explicit "unavailable" state — never a zeroed or invented quota.
- Cached/stale/expired results are visibly labeled as such.
- Product copy scopes the weekly number with the documented shared-with-Claude-chat caveat.
- Full Swift suite green (≥44 Claude tests + new tests), zero regressions; docs and planning board reconciled.
</content>
</invoke>
