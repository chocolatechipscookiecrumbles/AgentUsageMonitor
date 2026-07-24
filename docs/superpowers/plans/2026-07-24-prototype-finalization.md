# Prototype Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Follow `docs/development/evidence-rich-pull-requests.md` when preparing the PR.

**Goal:** Bring the multi-provider (Codex + Claude) menu-bar app from working prototype to a finalizable state: a real README and app icon, a menu-bar readout that shows *both* providers' usage, real Connect/Disconnect for every agent, a first-run authentication state inside the popover for both agents, and per-agent quota-warning settings backed by real per-agent notification delivery.

**Architecture:** Each item is an independent vertical slice through the existing owners — `QuotaViewModel` (state), `QuotaMonitor`/`ClaudeUsageMonitor` (read cycles), `QuotaNotifier` (delivery), `AppSettings` (persistence), and the menu/Settings SwiftUI surfaces. No new global owner is introduced; the largest structural change is generalizing today's Codex-only notification path into a provider-scoped one.

**Tech Stack:** Swift 6.2, SwiftUI for macOS 14+, AppKit `MenuBarExtra`/`NSImage`, `UserNotifications`, Swift Package Manager, `.xcassets`, signed-app acceptance.

## Global Constraints

- Work on `feature/prototype-finalization`; do not push or open a PR without explicit approval (the user handles PR creation).
- Preserve the shipped provider-switch geometry fix, the 288-point shared popover content floor, the tab hit-target contract, and the non-scrolling popover budget. Do not reintroduce a host resize on selection.
- Keep the Claude data path within the accepted personal-build boundary: OAuth reuse of Claude Code's Keychain credential → statusLine → cache. Do not add a new outbound path or a new automatic CLI probe (the consented manual "Force a reading" stays as-is).
- A real zero is not a missing value; keep availability explicit on every surface.
- Menu popover stays 340 points wide and non-scrolling; Settings pages keep their shared vertical `ScrollView`.
- Add narrow deterministic regression coverage only for reproduced defects and for new pure logic (presentation mappers, threshold scoping, notification policy). Do not add feature-presence tests. Private SwiftUI/AppKit compositing and hit-testing remain signed-app acceptance, not unit tests.
- The menu-bar popover branch visual/keyboard/VoiceOver verification waiver still applies: record those as unobserved unless the user operates them.
- Convert any relative dates to absolute in committed docs.

## Current Source State (grounded 2026-07-24)

- **README:** none at the repo root. Existing docs: `how-to.md`, `AGENTS.md`, `MISSION.md`, `CONTEXT.md`, `RESOURCES.md`, `UsageProbe/README.md`, and the `docs/` tree.
- **App icon:** `CodexUsageMonitor/Resources/Assets.xcassets` contains `Codex`, `Claude`, and `Copilot` imagesets but **no `AppIcon`**. `Info.plist` sets no icon.
- **Menu-bar label:** `Menu/MenuBarLabelPresentation.swift` — with multiple available providers it renders only the single `MenuProviderSummary.mostAtRisk` provider (percent + that provider's glyph). It does not show both providers at once.
- **Settings connections:**
  - `Settings/CodexAgentSettingsView.swift` — real "Connect with browser" / "Connect with Codex CLI…"; **Disconnect is a stub** (`Button("Disconnect") {}` with "Disconnect is planned").
  - `Settings/ClaudeAgentSettingsView.swift` — real "Connect" (Keychain credentials) and real "Disconnect" (`disconnect` closure).
- **Popover unavailable/auth surfaces already exist:** `Menu/CodexUnavailableContent.swift` + `Menu/CodexSignInActions.swift` (browser/CLI), and `Menu/ClaudeUnavailableContent.swift` + `Menu/ClaudeCredentialActions.swift` (Keychain). These are the reusable pieces for the first-run auth state.
- **Quota-warning settings:** `Settings/NotificationSettingsView.swift` hosts a global **"Remaining Quota"** section over `RemainingQuotaThreshold.allCases`, bound to `AppSettings.enabledQuotaThresholds` (single global set, key `notification.enabledQuotaThresholds`). `Settings/AgentUsageWarningsSection.swift` already exists and is wired into the Codex page **but maps to the same global store**; the Claude page does not use it yet.
- **Notifications are Codex-only:** `Notifications/QuotaNotifier.swift` is owned by `Monitoring/QuotaMonitor.swift` (Codex). Every title is hard-coded "Codex …"; `quotaAlerts` reads the global thresholds. `ClaudeUsageMonitor` delivers no notifications.

## Related deferred plans this touches

- Preferred/effective Menu Bar Agent and failover policy — `docs/superpowers/plans/2026-07-14-settings-provider-followups.md` (Task 7). The multi-provider readout here is a step toward it; keep the extraction boundary.
- Distinct menu-bar disconnected and cache markers — `docs/superpowers/plans/2026-07-17-distinct-menu-bar-status-markers.md` (deferred). Reconcile the multi-provider readout with those markers rather than duplicating.
- Claude / per-agent notifications — previously deferred pending "the proper menu-bar popover"; that gate is now met, so notification generalization is in scope here.

---

## Workstream A — Root README

**Goal:** A repo-root `README.md` that lets a new reader understand what the app is, what it reads, how to build/run the signed app, and where the durable docs live.

**Files:** Create `README.md`; cross-link `how-to.md`, `AGENTS.md`, `docs/product/planning-board.md`, `docs/development/evidence-rich-pull-requests.md`, `UsageProbe/README.md`.

- [ ] **Step 1:** Draft the README: one-paragraph product statement (personal multi-provider usage monitor for Codex + Claude), supported providers and their data sources with the privacy boundary (Claude OAuth/statusLine/cache; no outbound content), a build/run section (`swift build`, `swift test`, `CodexUsageMonitor/Scripts/build-app.sh`), a feature tour (menu-bar readout, popover, Settings), and a "durable docs" index.
- [ ] **Step 2:** State the personal, non-commercial scope and the Anthropic ToS caveat already recorded in the plans, so the README does not overclaim.
- [ ] **Step 3:** Verify links resolve and no build/verification claim is asserted as observed unless it was run.

## Workstream B — Multi-provider menu-bar readout

**Goal:** The menu-bar item shows usage for **both** connected providers at a glance — one glyph + percent per provider — while degrading cleanly to one provider or the unavailable label.

**Decision (2026-07-24, confirmed):**
- Format is **glyph + percent pairs**, one pair per available provider (e.g. `<glyph> 82% · <glyph> 40%`), using the existing provider assets and honoring `QuotaValueMode` and the pause/cache markers.
- Each provider contributes a **single "active window" percent**, not both windows: **default to the 5-hour window, fall back to the weekly window when there is no active 5-hour limit.** (Example: Codex with no active 5-hour limit shows its weekly figure; Claude shows its 5-hour figure.)
- A **stacked per-provider** variant (both windows per provider) is also wanted, **but is gated on UI drawing samples** — produce mockups and get the user's visual choice before implementing either the pair or the stacked layout.

**Blocked until:** UI drawing samples of the pair layout and the stacked layout are produced and the user picks one. Do not write production label code for Workstream B before that.

**Files:** `Menu/MenuBarLabelPresentation.swift`, `Menu/MenuBarLabelView.swift`, `Menu/MenuBarStatusLabel.swift`, `Menu/MenuProviderSummary.swift`; tests in `MenuProviderSummaryTests`/a new label test.

- [ ] **Step 0 (blocking):** Produce UI drawing samples for (a) the single-active-window glyph+percent pair layout and (b) the stacked per-provider layout, at realistic menu-bar widths in Light/Dark. Get the user's selection and record it here before coding.
- [ ] **Step 1:** Define the "active window" selector on `MenuProviderSummary` — prefer the 5-hour window, fall back to weekly when no active 5-hour limit exists — and expose the chosen percent + freshness per provider. Add a deterministic test for the selector (5-hour present, 5-hour absent → weekly, both absent → unavailable).
- [ ] **Step 2:** Extend `MenuBarLabelPresentation` with the selected multi-provider readout branch; keep the single-provider and unavailable branches unchanged. Preserve accessibility: one combined label naming each provider, its active-window percent, value mode, and freshness.
- [ ] **Step 3:** Update `MenuBarLabelView` to render the selected layout within the menu-bar width budget; fall back to text-only if width is constrained.
- [ ] **Step 4:** Reconcile with the deferred status-marker plan (disconnected vs cached vs confirmed) so the multi-provider readout does not contradict it.
- [ ] **Step 5:** Add deterministic presentation tests for two-provider, one-provider, mixed-availability, and all-unavailable cases. Signed-app visual acceptance for width/rendering.

## Workstream C — Real Connect/Disconnect for every agent

**Goal:** Both agent Settings pages expose working Connect and Disconnect actions with consistent copy and status, replacing the Codex disconnect stub.

**Files:** `Settings/CodexAgentSettingsView.swift`, `Connection/CodexConnectionController.swift` (owner of Codex connection state), `Menu/QuotaViewModel.swift` (expose a `disconnectCodex` action), `Settings/ClaudeAgentSettingsView.swift` (consistency pass only).

- [ ] **Step 1 (decision — confirmed 2026-07-24):** Codex disconnect is **app-local only** — clear the app's cached Codex snapshot/connection and stop showing usage, leaving the Codex CLI session and stored credential untouched. This matches Claude's disconnect and the personal-build boundary.
- [ ] **Step 2:** Implement the chosen `disconnectCodex` on the connection owner and expose it through `QuotaViewModel`, mirroring `disconnectClaude`. Add a deterministic state-transition test (connected → disconnected → reconnect).
- [ ] **Step 3:** Replace the Codex `Button("Disconnect") {}` stub with the real action and accurate guidance copy (what it does and does not touch). Keep the disabled/enabled rules aligned with `signInDisabled`.
- [ ] **Step 4:** Align Claude's Connect/Disconnect copy and status wording with Codex so both pages read as one system. No behavior change to Claude's working path beyond copy.
- [ ] **Step 5:** Signed-app acceptance: connect, disconnect, reconnect on both pages; confirm the menu-bar readout and popover reflect each transition.

## Workstream D — Popover first-run authentication state

**Goal:** When a provider has never been set up, its popover tab shows a clear "authenticate to get started" state that reuses the existing sign-in affordances — Codex browser + CLI, Claude Keychain — distinct from the transient "connected, no snapshot yet" state.

**Files:** `Menu/CodexUnavailableContent.swift`, `Menu/CodexSignInActions.swift`, `Menu/ClaudeUnavailableContent.swift`, `Menu/ClaudeCredentialActions.swift`, `Menu/CodexMenuContent.swift`, `Menu/ClaudeMenuContent.swift`, `Menu/MenuBarPopoverView.swift`; setup-state resolvers already in `QuotaViewModel`/`ClaudeUsageMonitor`.

- [ ] **Step 1:** Define the first-run condition per provider from existing setup state (Codex: `.disconnected`/never-signed-in; Claude: `ClaudeSetupState` first-run vs lapse — already distinguished). Do not treat a normal "not connected but passively capturable" Claude account as first-run.
- [ ] **Step 2:** Render a first-run auth card on each tab that reuses `CodexSignInActions` (browser + CLI) and `ClaudeCredentialActions` (Keychain connect), with concise onboarding copy. Keep the existing unavailable/recovery cards for the non-first-run cases; do not show disabled sign-in buttons in the reachable "connected, no snapshot yet" state (already fixed for Codex — preserve it).
- [ ] **Step 3:** Ensure the first-run action dismisses/opens correctly (browser/CLI flows) and that completing auth transitions the tab to normal content without a host resize (respect the shared content floor).
- [ ] **Step 4:** Keep provider content bounded and non-scrolling. Add a presentation test for the first-run vs unavailable vs recovery decision per provider. Signed-app acceptance of both first-run flows.

## Workstream E — Per-agent quota warnings + real per-agent notifications

**Goal:** Move the "Remaining Quota" threshold controls off the global Notifications page and into each agent's page, backed by a per-provider threshold store, and deliver real notifications for **both** providers (not just Codex).

**Files:** `Settings/NotificationSettingsView.swift` (remove the global Remaining Quota section), `Settings/AgentUsageWarningsSection.swift` (already reusable), `Settings/CodexAgentSettingsView.swift` + `Settings/ClaudeAgentSettingsView.swift` (host the section), `Settings/AppSettings.swift` (per-provider threshold storage + migration), `Notifications/QuotaNotifier.swift` (provider-scoped alerts), `Monitoring/QuotaMonitor.swift` + `Quota/ClaudeUsageMonitor.swift` (invoke delivery), and notifier/threshold tests.

- [ ] **Step 1:** Add per-provider threshold storage to `AppSettings` (e.g. `enabledQuotaThresholds(for: AgentProvider)`), keyed per provider, **migrating** the existing global `notification.enabledQuotaThresholds` into each active provider's set so no user setting is lost. Keep `alertsEnabled` global (the master permission gate). Add a migration test (old global value → both providers) and per-provider get/set tests.
- [ ] **Step 2:** Wire `AgentUsageWarningsSection` into the Claude page and repoint both pages' bindings to the provider-scoped store. Remove the "Remaining Quota" section from `NotificationSettingsView`; leave the master toggle, permission status, and non-quota "Other Warnings" there. Update `NotificationSettingsContextView` copy if it references the moved control.
- [ ] **Step 2b (decision — confirmed 2026-07-24):** The non-quota "Other Warnings" (forecast, reset, stale, refresh-failure) **stay global** on the Notifications page. Only the remaining-quota thresholds move per-agent.
- [ ] **Step 3:** Generalize `QuotaNotifier` so alert identity, copy, and threshold lookup are provider-scoped (title names the provider; dedup keys include the provider; thresholds read per provider). Preserve existing Codex dedup keys via a compatibility path so a rename does not re-alert an already-notified Codex episode.
- [ ] **Step 4:** Give `ClaudeUsageMonitor` a delivery path: on each confirmed read, evaluate the Claude five-hour/weekly windows against Claude's thresholds through the shared notifier, reusing the same authorization gate and one-shot dedup discipline. Keep `QuotaMonitor` as Codex's caller. Do not add a second scheduler.
- [ ] **Step 5:** Regression coverage: a Claude window crossing a threshold delivers exactly once per episode and not again on later reads; a real zero alerts while a missing value does not; the migration preserves prior Codex thresholds. Signed-app acceptance for at least one real delivery per provider where feasible (record unobserved states honestly).

## Workstream F — Application icon

**Goal:** The app ships with a real macOS application icon.

**Files:** Create `CodexUsageMonitor/Resources/Assets.xcassets/AppIcon.appiconset` (all required sizes), reference it from `Info.plist`/the asset catalog, and confirm `build-app.sh` packages it.

- [ ] **Step 1 (asset — decision confirmed 2026-07-24):** The **user supplies the icon artwork**. This workstream wires whatever art the user provides; it does not design the icon. When the artwork arrives, generate the required 16–1024 pt sizes for the appiconset.
- [ ] **Step 2:** Add the `AppIcon.appiconset` to the catalog and set `CFBundleIconName`/icon reference so AppKit loads it; ensure the menu-bar template glyph (status item) is unaffected.
- [ ] **Step 3:** Build the signed app via `build-app.sh` and confirm the icon appears in Finder, the Dock (if shown), and the About box. Record observed vs not-run.

---

## Sequencing and dependencies

1. **E (per-agent notifications)** and **C (disconnect)** touch the deepest owners (`AppSettings`, `QuotaNotifier`, connection controllers); land them as separate reviewable slices first.
2. **B (menu readout)** and **D (popover first-run)** are presentation slices that can follow independently.
3. **A (README)** and **F (app icon)** are non-code/asset slices; do them last so the README describes the final behavior and the icon reflects the finished product.

Prefer one focused PR per workstream (or per small group) over one omnibus PR, per the evidence-rich-PR guide.

## Decisions (resolved 2026-07-24)

- **B — menu-bar format:** glyph + percent pairs, one per provider, each showing a single active window (5-hour default → weekly fallback). A stacked per-provider variant is also wanted. **Still open:** which layout ships — gated on UI drawing samples (Workstream B, Step 0). This is the one remaining blocker before any B code.
- **C — Codex disconnect:** app-local only (leaves CLI session and credential untouched).
- **E/2b — Other Warnings:** stay global; only remaining-quota thresholds move per-agent.
- **F — app icon:** user supplies the artwork; this workstream only wires it.

## Documentation and acceptance

- Update `docs/product/planning-board.md` (new rows per workstream), the relevant deferred plans (mark superseded scope), `AGENTS.md` (only durable invariants — e.g. provider-scoped notification identity, per-agent threshold store), `how-to.md`, and `UsageProbe/README.md` where user-visible behavior changes.
- Each workstream's PR must separate Run / Observed / Not run evidence and keep the menu-bar popover visual/keyboard/VoiceOver waiver explicit.

## Additional candidate touches (flagged, not committed)

Noticed while grounding this plan; confirm before adding scope:

- First-run onboarding consistency between `ClaudeSetupOnboardingView` and a (currently absent) Codex onboarding equivalent.
- Reconciling the deferred "distinct menu-bar status markers" plan into Workstream B rather than leaving it separate.
- Developer ID signing finalization (previously gated behind "proper popover + per-agent notifications", both of which this plan completes).
