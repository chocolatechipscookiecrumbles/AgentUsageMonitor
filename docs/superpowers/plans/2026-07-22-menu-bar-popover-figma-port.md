# Menu Bar Popover — Figma v6 Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current plain `MenuBarExtra` menu with a SwiftUI port of the **v6 Figma menu bar popover** — a 340pt card with a provider tab strip, progress ring, window cards, freshness metadata, and a bottom action menu. Design reference and extracted tokens live in [docs/design/menu-bar-popover/](../../design/menu-bar-popover/SPEC.md).

**Supersedes** [2026-07-22-multiprovider-menubar-popover.md](2026-07-22-multiprovider-menubar-popover.md). That plan was written before the Figma export was reviewed and independently proposed a provider tab strip; the design already specifies one, so this plan absorbs it. The earlier plan's two hard findings still hold and are carried forward below.

## Layout revision (2026-07-22)

The exported layout was revised before porting — see [SPEC §6](../../design/menu-bar-popover/SPEC.md#6-revision--2026-07-22-supersedes-the-raw-v6-export). Summary:

- **Removed:** the header "Refresh Now" pill (duplicate — the action stays in the bottom menu), the **entire primary quota card** (plan name, "Lowest remaining", the 64pt ring), and the **entire freshness metadata card** (Collected/Source/Confirmation/Collector).
- **Moved:** the status pill from inside the primary card to the **header's right slot**.
- **Changed:** the header icon from a generic gradient glyph to the **active provider's own mark** (assets already in `reference/`).

Net effect: a shorter popover that is tabs → header (icon, title, pill) → window cards → credits (Codex only) → action menu. Port against SPEC §3, not against `reference/MenuBarDropdown.tsx`.

**Visual target update (2026-07-23):** the user-supplied updated screenshot is the visual acceptance target for the port. SPEC §3 remains the durable written contract and should be reconciled to that screenshot if a later implementation detail is ambiguous.

## Where this sits (state as of 2026-07-22)

- **Current menu is 168 lines of plain rows** across [QuotaMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift) (31), [ConnectedQuotaMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift) (66) and [CodexDisconnectedMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexDisconnectedMenuView.swift) (71). It is Codex-only and has no provider concept.
- **Claude usage is already live** in Settings via `ClaudeUsageMonitor` → `ClaudeUsageDisplayModel`. The Claude tab consumes that mapper; it must not be reimplemented.
- **The Figma export is untracked** in git. `docs/design/menu-bar-popover/` is now the durable copy — treat it, not the loose folder, as the source of truth.

## Two blockers that must be settled first

**1. `MenuBarExtra`'s default `.menu` style cannot render this design.** It draws a native system menu of rows; a 340pt card with tabs and rings requires `.menuBarExtraStyle(.window)`. That switch **loses native menu behaviors** — automatic dismissal on action, keyboard traversal, standard metrics and highlighting. Every one of those must be re-implemented or consciously accepted. This is the single largest regression risk in the port and is why Task 1 exists.

**2. One menu bar label, several providers.** The design does not address the label at all. With Codex and Claude both live there is one glyph slot for two numbers. Carried from the superseded plan: recommended rule is **worst-case across providers**, shown **only with a provider glyph** — a bare percentage that silently switches which provider it refers to is misleading. Settle in Task 2.

## Design defects — do not port verbatim

From [SPEC.md §5](../../design/menu-bar-popover/SPEC.md):

1. **The "% used" number is wrong.** `WindowCard` renders `{remaining}% used` while also rendering `Remaining {remaining}%` — the same figure labelled two contradictory ways, and the first label is incorrect (61% used displays as "39% used"). Port as `{usedPct}% used`, or keep only "Remaining".
2. **Drop the `copilot` tab** — its capability gate has not passed; a tab with no real read is the "static preview" problem again.
3. **Header and `Collector` row are Codex-branded on every tab** — must be per-provider.
4. **The credits card is Codex-only** — Claude has no credit balance; must be conditional.
5. **No sign-in/disconnected state exists in the design** — Codex's browser/CLI sign-in and Claude's credential affordances need a home.

## Architecture

- **`MenuPopoverTheme`** — the tokens from SPEC §1–2 as a single Swift type (surfaces, radii, shadows, semantic colors, the ≤10/≤25 threshold rule) so no view hardcodes a hex.
- **`MenuPopoverChrome`** — shell: 340pt card, radius, border, shadow, window/card surfaces, light+dark.
- **Primitives**: `UsageProgressBar` (4pt), `StatusPill` (now header-mounted), `ProviderIconTile` (28pt, radius 8, renders the active provider's mark). The `UsageProgressRing` and `MetadataRow` primitives are **no longer needed** — the revision removed the primary quota card and the freshness metadata card.
- **`MenuProviderTabStrip`** — driven by `AgentProvider` (already carries `tabTitle`, `systemImage`, tint) filtered to providers with a real read.
- **`CodexMenuContent`** — window cards + credits card, mapped from the existing `QuotaPresentation`/`QuotaDisplayState`. **Behavior-preserving**: every affordance in today's menu must survive. Per the revision, there is no primary quota card and no freshness metadata card.
- **`ClaudeMenuContent`** — 5h/7d window cards, shared-pool caveat, explicit unavailable state, built from `ClaudeUsageDisplayModel`. No credits card. **Open question from the revision:** provenance (OAuth vs statusLine vs cache) has no home now that the metadata card is gone — see Task 5a.
- **`MenuActionFooter`** — Refresh Now / Notification Settings / Preferences… / Quit.
- **Presentation stays in testable structs** (`MenuBarLabelPresentation`, `ClaudeUsageDisplayModel`, a new `CodexMenuPresentation`), never in view bodies.

**Tech Stack:** SwiftUI, Combine, XCTest for the preserved existing suite. No new dependencies. SVG provider marks in `docs/design/menu-bar-popover/reference/` may be converted to asset catalog entries; do not redraw or substitute those Figma-owned marks.

## Global constraints

- **No provider tab without a real read** (generalizes the Claude capability gate).
- **The label never shows a bare percentage** without identifying its provider.
- **Never render a missing value as `0%`** — absent data shows as unavailable, per gate criterion #5.
- **Cached/stale/expired must stay visibly labelled** (probe plan §7/§9) — the design's amber "Showing Last Confirmed Snapshot" strip satisfies this for Codex; Claude's equivalent comes from `stalenessNotice`.
- **No behavior regressions in the Codex menu.** Sign-in, alerts toggle, refresh, notification-settings link, forecasts all keep working.
- **Current regression-test policy overrides the test-first language in later tasks (2026-07-23).** Preserve and run the existing suite. Do not add feature-presence, routing, happy-path, implementation-detail, or broad general tests. Add only the smallest deterministic regression test when an actual defect has first been reproduced; otherwise record the manual regression boundary and why it remains manual.
- **Opening the popover is not a refresh trigger.** Refresh continues to follow the existing scheduler and explicit Refresh Now action.
- **Build acceptance for this port uses `Scripts/build-app.sh`.** A local/ad-hoc signature is sufficient during implementation; do not require a Developer ID signature.

### Visual-verification waiver (2026-07-23)

The user explicitly waived the remaining GUI, keyboard, VoiceOver, and Light/Dark visual-verification steps for this branch and directed implementation to continue. Those states remain **unobserved**, not passed. Source review, compilation, and the preserved automated regression suite remain required; later manual acceptance can resume from the unchecked visual states without inferring coverage.

---

## Task 1: Prove `.window` style is viable (SPIKE — gate)

**Why first:** if popover dismissal can't be made to work acceptably, the whole port is in question and it is far cheaper to learn that now.

- [x] **Step 1:** Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)` with a placeholder 340pt card behind a temporary flag.
- [ ] **Step 2:** Manually verify and **write down** the result for: clicking an action dismisses the popover; clicking outside dismisses; Escape dismisses; the menu bar icon toggles; VoiceOver/keyboard focus is not trapped.
- [x] **Step 3:** If dismissal does not work by default, implement it explicitly (e.g. an environment-injected dismiss handler each action calls) and re-verify.
- [x] **Step 4: Record the finding** in this plan. If unresolvable, stop and reconsider — a popover that will not close is worse than a plain menu. **Commit.**

### Task 1 gate implementation and pending acceptance (2026-07-23)

Launch the locally built app with `--window-popover-gate` to install a dedicated `.window` `MenuBarExtra`; SwiftUI requires the scene declarations to remain static, so mutually exclusive `isInserted` bindings keep only the selected item in the menu bar. Launching without the argument installs the shipping `.menu` surface instead. The gate renders a 340-point placeholder with native, labelled buttons and no open-triggered task or refresh call. Both actions call SwiftUI's presentation-scoped `DismissAction`; Escape is also bound to the Close Popover action. Open Settings dismisses before changing application activation.

Build and source inspection established that the gate is reachable, scoped, and does not refresh on open. Controller inspection after the startup fix established the directly observed native behavior recorded below. Step 2 remains unchecked because keyboard activation and VoiceOver focus escape could not be observed; no result is inferred for those blocked states.

#### Task 1 audit-launch startup defect and fix (2026-07-23)

The first unlocked GUI launch with `--window-popover-gate` reproduced a real defect before the placeholder could be audited: `QuotaViewModel.init()` still called its normal `start()` fan-out, which starts the Codex connection check, Codex quota monitor, Claude usage monitor, and notification-authorization refresh. The Claude launch read raised a Claude Code Keychain permission dialog. The controller terminated only the audit app without responding. Later inspection established that the stale dialog survives process termination, predates the fixed audit launch, and was not answered.

The audit argument now participates in `QuotaViewModel.shouldStartProviderMonitoring(arguments:)`. That policy returns false for the window-popover gate, so the audit launch constructs the state needed by the scene but starts no provider monitors, connection checks, refreshes, notification authorization, or credential reads. Normal launches retain the existing startup path.

This reproduced defect qualifies for the repository's narrow regression exception. `QuotaViewModelLaunchPolicyTests.testWindowPopoverGateDoesNotStartProviderMonitoring` protects only the startup decision: its red run failed because the policy boundary did not exist; its green run passed after the gate exclusion. The post-fix full suite passed 223 tests with zero failures before the fix commit.

#### Task 1 controller GUI evidence after `1604595` (2026-07-23)

The controller launched the rebuilt audit app with `--window-popover-gate` and directly observed:

- [x] the 340-point window-style popover rendered;
- [x] the fixed audit launch started no new provider monitoring;
- [x] **Close Popover** dismissed on the first action;
- [x] **Open Settings…** dismissed the popover and opened Settings;
- [x] clicking outside dismissed;
- [x] Escape dismissed;
- [x] clicking the menu bar item reopened the popover after dismissal;
- [x] repeated manual open/close cycles left no stuck state;
- [ ] Tab/Shift-Tab focus traversal;
- [ ] Return/Space activation of the focused action;
- [ ] VoiceOver focus entry and escape.

The last three states remain unobserved because an outstanding SecurityAgent Claude credential prompt owns keyboard and accessibility focus. That stale prompt survives even after the audit process is terminated, demonstrating that it predates and is independent of the fixed audit launch; it was not answered during this audit.

Screenshot evidence:

- outside-open state: `/private/tmp/gate-outside-open.png`;
- outside-dismissed state: `/private/tmp/gate-outside-closed.png`;
- Escape-dismissed state: `/private/tmp/gate-escape-closed.png`;
- Open Settings result: `/private/tmp/gate-open-settings-result.png`.

The observed mouse dismissal, Escape, reopen, and repeated-cycle behavior make the `.window` presentation viable for continued implementation. Task 1 remains partially open only for the keyboard and VoiceOver checks blocked by SecurityAgent focus.

## Task 2: Settle the multi-provider label rule

- [x] **Step 1: Skipped by repository policy.** No reproducible defect preceded this new feature, so no feature-presence tests were added. `MenuProviderSummary` still keeps availability explicit rather than representing a missing read as zero.
- [x] **Step 2: Skipped with Step 1.** The existing suite was preserved and run after implementation.
- [x] **Step 3:** Record the chosen rule in this plan, then implement `MenuProviderSummary` + selection.
- [x] **Step 4:** Extend `MenuBarLabelPresentation`: one provider → unchanged from today (no regression); two → at-risk provider **with glyph**; none → existing unavailable label. **Run the full suite. Commit.**

### Task 2 label decision and implementation (2026-07-23)

The menu-bar label selects the provider with the **highest used percentage across its available windows**. Missing windows and providers with no usage read are excluded; they never participate as `0%`. Equal utilization resolves in stable provider order: Codex, Claude, then any future capable provider. The selected provider does not change when the user's display mode changes: **Used** shows its utilization, while **Remaining** shows the complement for that same at-risk provider.

With only Codex data available, `MenuBarLabelPresentation` delegates to the original Codex-only initializer byte-for-byte, preserving both existing display styles, gauge behavior, cached pause marker, accessibility copy, and unavailable fallback. When Claude is the only available read or both providers have data, the compact label shows the selected value with that provider's bundled mark. Each available summary couples its utilization with typed freshness: Codex maps confirmed/cached display mode, while Claude maps live/cached/passive delivery. A selected non-confirmed reading carries the compact pause marker, and accessibility names the provider and its confirmed, cached, or passive state. `MenuBarStatusLabel` derives Codex and Claude summaries from their existing display models and performs no refresh. The full existing suite passed 223 tests with zero failures. The provider-glyph and non-confirmed-marker rendering remain visually unobserved under the user waiver above.

## Task 3: Theme and primitives

- [x] **Step 1: Skipped by repository policy.** Theme and primitive presence is new-feature coverage, not a reproducible defect regression, so no new tests were added.
- [x] **Step 2: Skipped with Step 1.** The existing suite is preserved and run after implementation.
- [x] **Step 3: Implement** `MenuPopoverTheme`, `UsageProgressBar`, `StatusPill`, and `ProviderIconTile` per SPEC §1–2 and the 2026-07-22 revision. The removed `UsageProgressRing` and `MetadataRow` are intentionally not implemented.
- [x] **Step 4:** `swift build --disable-sandbox` succeeded, the ad-hoc
  `Scripts/build-app.sh` bundle build succeeded, and the unchanged full suite
  passed 223 tests with zero failures. Commit.

Visual acceptance of the Task 3 primitives is unobserved under the user's
explicit waiver. Light and Dark appearances, provider marks, threshold colors,
and status-pill states were not directly inspected.

## Task 4: Shell + provider tab strip

- [x] **Step 1: Skipped by repository policy.** Provider routing and selection fallback are new-feature coverage, not a reproduced defect, so no tests were added.
- [x] **Step 2: Skipped with Step 1.**
- [x] **Step 3: Implement** `MenuPopoverChrome` + `MenuProviderTabStrip` + the header row (using the Task 3 `ProviderIconTile`, title/subtitle, and status pill) + the root `MenuBarPopoverView` (strip, header, content, footer). The provider marks are full-color SVGs; Task 3 deliberately placed them on a low-emphasis provider-tinted surface rather than reusing the old blue-violet gradient.
- [x] **Step 4:** `swift build --disable-sandbox` succeeded and the unchanged full suite passed 223 tests with zero failures. Commit.

### Task 4 provider-availability reconciliation (2026-07-23)

“Provider with a real read” is a capability/support gate, not a requirement
that a usable snapshot exist at the instant the popover opens. Claude passed
that gate and is marked `.supported` in `AgentSettingsCatalog`, so the
production strip consistently contains Codex and Claude. This is required for
Task 6's Claude unavailable/setup state to remain reachable. Copilot is absent
because it has no supported catalog entry. A requested unsupported selection
(including a future persisted Copilot value) resolves to the first supported
provider instead of presenting empty content.

The shipping `MenuBarExtra` now uses `.window` presentation and hosts the
340-point shell, provider tabs, provider-specific header, temporary content
slots for Tasks 5 and 6, and the action footer. Refresh dispatches explicitly
to the selected provider and opening the popover performs no refresh.
Notification Settings opens the app's Notifications destination, Preferences
opens General, and each command dismisses the popover before continuing.
The existing menu-bar status label is unchanged and the old native-menu views
remain until Task 8 confirms that their affordances have all been ported.

#### Task 4 refresh-state review fix (2026-07-23)

Review found that Claude refreshes had no in-flight owner: each footer action
could create another untracked task, while the Claude header and footer stayed
enabled. `QuotaViewModel` now owns one Claude refresh task and publishes
`isRefreshingClaude`; a second explicit refresh is ignored until the first
read completes. The Claude header now presents **Refreshing…** and the shared
footer disables the active provider's Refresh Now action for both providers.
The explicit Claude action retains its user-initiated Keychain prompt policy.
This was identified by source tracing; no new test was added under the
repository's regression-only policy, and the existing full suite passed.

Visual, keyboard, VoiceOver, and Light/Dark verification for this task remain
unobserved under the user waiver above.

## Task 5: Codex content — behavior-preserving port

- [x] **Step 1–2 (tests): superseded by the repository test policy.** The SDD policy for this branch is "no new feature-presence tests; add only narrow regression coverage for reproduced defects." The TDD-first steps from the original brief were therefore not taken: `CodexMenuPresentation` is new but purely behavior-preserving mapping over the existing `QuotaPresentation`/`QuotaDisplayState`, and design defect #1 (`% used` shows used, not remaining) is deliberately *preserved* in the revision, so no failing test was warranted. The existing 223-test suite is the automated baseline.
- [x] **Step 3: Implemented** `CodexMenuContent` from `QuotaPresentation`/`QuotaDisplayState` — cached warning strip (SPEC §47 wording "Showing Last Confirmed Snapshot"), two window rows (used% right, remaining% + reset timing footer, forecast line), optional credits card, quota-alerts card with denied-notification recovery, connection-recovery card when disconnected-with-cache, and the unavailable/sign-in card.
- [x] **Step 4: Behavior preservation reviewed against the old menu views.** Every affordance from `ConnectedQuotaMenuView`/`CodexDisconnectedMenuView`/`QuotaMenuView` is carried across: browser + CLI sign-in, quota-alerts toggle, denied-notification recovery link, footer Refresh Now, notification-settings link, forecasts, reset credits, Settings, quit. Intentionally not re-added (they live in Settings or the header now): plan tier, pause-reason detail (SPEC §47 fixes the strip text), the next-refresh-timing card (the header's "Updated HH:MM:SS" carries freshness). **Review fix applied:** `CodexUnavailableContent` no longer renders disabled sign-in buttons when `state == .connected` (the reachable "connected but no snapshot yet" state); that card now relies on the footer's Refresh Now, which its own copy already directs the user to.

**Visual/keyboard/VoiceOver/Light-Dark states are waived for this branch and recorded as unobserved, never passed.** Verified: `swift build`, full 223-test suite, and `git diff --check` all pass.

## Task 5a: Decide where the removed information goes (DESIGN GATE)

The revision removed three pieces of information from the popover. Settled below (decisions recorded 2026-07-23) before building Claude's tab, since two of them affect it directly.

- [x] **Plan name** ("Pro") — **Decision: plan tier lives only in Settings.** It has no home in the revised popover and is not re-added on either tab. The header title names the provider ("Codex Usage Monitor" / "Claude Usage Monitor"); tier is not identity and Settings already presents it. No Codex plan-name furniture, and Claude's tab does not add a plan card either.
- [x] **"Lowest remaining %"** — **Decision: per-window values plus the menu-bar label carry this role.** Each window row shows real `used%` (right) and `remaining%` (footer); the at-a-glance at-risk signal is the menu-bar label's Task 2 rule (highest used% across available windows, provider-identified). No ring or single lowest-remaining figure returns to the popover.
- [x] **Provenance** (`Source` / `Collector`) — **Decision: Claude provenance goes in the header subtitle alongside freshness time (source + updated time); the status pill/strip keeps freshness state.** Because Claude's data can come from OAuth, a statusLine capture, or cache — materially different in authority — the source label must stay visible on the menu, not only in Settings. It rides in the header subtitle (e.g. "OAuth · Updated HH:MM:SS"), while the status pill continues to signal confirmed/cached and the staleness strip continues to flag stale reads. Codex keeps its plainer "Updated HH:MM:SS" subtitle (single collector, no provenance ambiguity) and shows no "Collector: …" furniture.
- [x] **Committed** as this plan edit before Task 6.

## Task 6: Claude content

- [ ] **Step 1: Implement** `ClaudeMenuContent` from `ClaudeUsageDisplayModel`: plan, five-hour and weekly window cards, source label + relative capture time, the shared-pool caveat, `stalenessNotice` surfaced like the Codex cached strip, and the explicit unavailable state with the credential affordance.
- [ ] **Step 2:** Hide Codex-only furniture (credits card, `Collector: Codex App Server`) on this tab; the header must name the active provider.
- [ ] **Step 3:** Manual verification against the live account. **Commit.**

## Task 7: Persist the selected tab

- [ ] **Step 1: Failing tests**: selection round-trips through `AppSettings`; an unavailable persisted provider falls back rather than showing an empty tab.
- [ ] **Step 2: Implement. Run the full suite. Commit.**

## Task 8: Retire the old menu and document

- [ ] **Step 1:** Remove `QuotaMenuView`/`ConnectedQuotaMenuView`/`CodexDisconnectedMenuView` once their affordances are confirmed ported. Keep `CodexDisconnectedMenuView`'s sign-in copy if reused.
- [ ] **Step 2:** Update the planning board and extend [the verification guide](../../claude-usage-verification.md) with menu-level manual checks.
- [ ] **Step 3: Commit.**

---

## Explicitly deferred (not dropped)

- **GitHub Copilot tab** — blocked on its capability gate.
- **Per-provider view models.** `QuotaViewModel` stays one type; splitting it collides with recent changes and should follow this port.
- **Desktop widget / watch complication** — the export also contains `DesktopWidget.tsx` and `WatchComplication.tsx`; out of scope here.
- **Tab reordering / pinned primary provider** — depends on Task 2's outcome.

## Completion criteria

- The menu bar shows the revised v6 popover: 340pt card, provider tabs (Codex + Claude only), header with the active provider's icon and the status pill, window cards, credits (Codex only), action footer — light and dark.
- **The popover dismisses correctly** after every action (Task 1's gate).
- Every Codex affordance from the old menu still works; no data regression.
- Claude's tab labels stale/cached data and shows an explicit unavailable state rather than zeros.
- The `% used` defect is fixed, not ported.
- The label never shows a bare percentage without its provider.
- Full suite green.
