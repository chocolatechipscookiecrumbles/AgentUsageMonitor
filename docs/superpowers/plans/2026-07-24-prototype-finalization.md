# Prototype Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Follow `docs/development/evidence-rich-pull-requests.md` when preparing the PR.

**Goal:** Bring the multi-provider (Codex + Claude) menu-bar app from working prototype to a finalizable state: a real README (modeled on prior art) and app icon, a standardized Connect/Disconnect for every agent, a first-run authentication state inside the popover for both agents, per-agent quota-warning settings backed by real per-agent notification delivery, and a consistent refresh cadence across all agents. (A both-providers menu-bar readout is planned but **skipped for now** by user direction.)

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

**Reference prior art (structure only, not copy):**
- [steipete/CodexBar](https://github.com/steipete/CodexBar) — a macOS 14+ menu-bar usage monitor. Useful structural patterns: a one-line tagline ("Every AI coding limit, in your menu bar"); leads with concrete use cases before features; badges (release, macOS requirement, install methods); a "Why" problem statement; prominent install/first-run/CLI setup; a provider table linking to per-provider docs; a **privacy & permissions** section stated upfront; and a docs index (architecture/development/config).
- [Javis603/token-monitor](https://github.com/Javis603/token-monitor) — a cross-platform token/usage monitor. Useful patterns: feature badges upfront; a provider capability **table** (token usage / limits detection / session detail); a **local-vs-sync architecture diagram**; per-platform install with code-signing notes; a build-from-source guide; and privacy-forward positioning ("prompts, responses, source code stay on your machine").

Adopt the *shape* (tagline → why → install/build → provider/data-source table → privacy → docs index), sized to this app's actual, smaller provider set (Codex + Claude). Do not copy their text, and do not claim providers or features this app does not have.

**Files:** Create `README.md`; cross-link `how-to.md`, `AGENTS.md`, `docs/product/planning-board.md`, `docs/development/evidence-rich-pull-requests.md`, `UsageProbe/README.md`.

- [ ] **Step 1:** Draft the README following the reference shape: tagline + one-paragraph product statement (personal multi-provider usage monitor for Codex + Claude); a provider/data-source table with the privacy boundary per provider (Claude OAuth/statusLine/cache; no outbound content; Codex app-server read); a build/run section (`swift build`, `swift test`, `CodexUsageMonitor/Scripts/build-app.sh`); a feature tour (menu-bar readout, popover, per-agent Settings, notifications); and a "durable docs" index.
- [ ] **Step 2:** Include a compact architecture note (owners: `QuotaViewModel`, `QuotaMonitor`/`ClaudeUsageMonitor`, `QuotaNotifier`) in the token-monitor spirit, and state the personal, non-commercial scope + the Anthropic ToS caveat already recorded in the plans, so the README does not overclaim.
- [ ] **Step 3:** Verify links resolve and no build/verification claim is asserted as observed unless it was run.

## Workstream B — Multi-provider menu-bar readout — SKIPPED FOR NOW

**Status (2026-07-24): deferred by user direction — "don't generate the menubar icons, skip that part for now."** Do not produce menu-bar icon/label samples or write Workstream B code in the current pass. The confirmed format decision below is preserved for when B resumes; the UI-drawing-samples step remains its entry gate. Nothing else in this plan depends on B.

**Goal:** The menu-bar item shows usage for **both** connected providers at a glance — one glyph + percent per provider — while degrading cleanly to one provider or the unavailable label.

**Decision (2026-07-24, confirmed — retained for resumption):**
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

## Workstream C — Standardized Connect/Disconnect for every agent

**Goal:** A **single, standardized Disconnect control** (shared component with consistent label, placement, confirmation, and disabled rules) used on every agent page, **wired per-provider** to each provider's own disconnect mechanism. Replaces the Codex disconnect stub and de-duplicates the two hand-rolled connection-action blocks.

**Design (2026-07-24):** The disconnect button is the same reusable view for all agents — one visual/interaction contract. What differs per provider is only the injected action and the "what this touches" guidance, because each provider is connected differently (Codex via browser/CLI session; Claude via the Keychain credential read). The component takes a provider tint, a disconnect closure, an enabled/confirmation policy, and provider-specific guidance copy. Connect affordances stay provider-specific (Codex browser+CLI vs Claude Keychain) since those genuinely differ, but the **Disconnect** affordance is unified.

**Files:** Create a shared `Settings/AgentDisconnectButton.swift` (standardized control); `Settings/CodexAgentSettingsView.swift` and `Settings/ClaudeAgentSettingsView.swift` (adopt it); `Connection/CodexConnectionController.swift` (owner of Codex connection state); `Menu/QuotaViewModel.swift` (expose `disconnectCodex`, mirroring `disconnectClaude`).

- [ ] **Step 1 (decision — confirmed 2026-07-24):** Codex disconnect is **app-local only** — clear the app's cached Codex snapshot/connection and stop showing usage, leaving the Codex CLI session and stored credential untouched. This matches Claude's disconnect and the personal-build boundary.
- [ ] **Step 2:** Implement `disconnectCodex` on the connection owner and expose it through `QuotaViewModel`, mirroring `disconnectClaude`. Add a deterministic state-transition test (connected → disconnected → reconnect).
- [ ] **Step 3:** Build the standardized `AgentDisconnectButton` (shared label, confirmation, disabled-while-signing-in rule, provider tint, injected action + guidance). Keep the shown-only-when-connected rule.
- [ ] **Step 4:** Adopt `AgentDisconnectButton` on both agent pages — Codex wired to `disconnectCodex` (replacing the `Button("Disconnect") {}` stub), Claude wired to its existing `disconnect`. Align surrounding Connect/status copy so both pages read as one system.
- [ ] **Step 5:** Signed-app acceptance: connect, disconnect, reconnect on both pages via the identical control; confirm the popover (and, once B resumes, the menu-bar readout) reflect each transition.

## Workstream D — Popover first-run authentication state

**Goal:** When a provider has never been set up, its popover tab shows a clear "authenticate to get started" state that reuses the existing sign-in affordances — Codex browser + CLI, Claude Keychain — distinct from the transient "connected, no snapshot yet" state.

**Files:** `Menu/CodexUnavailableContent.swift`, `Menu/CodexSignInActions.swift`, `Menu/ClaudeUnavailableContent.swift`, `Menu/ClaudeCredentialActions.swift`, `Menu/CodexMenuContent.swift`, `Menu/ClaudeMenuContent.swift`, `Menu/MenuBarPopoverView.swift`; setup-state resolvers already in `QuotaViewModel`/`ClaudeUsageMonitor`.

- [ ] **Step 1:** Define the first-run condition per provider from existing setup state (Codex: `.disconnected`/never-signed-in; Claude: `ClaudeSetupState` first-run vs lapse — already distinguished). Do not treat a normal "not connected but passively capturable" Claude account as first-run.
- [ ] **Step 2:** Render a first-run auth card on each tab that reuses `CodexSignInActions` (browser + CLI) and `ClaudeCredentialActions` (Keychain connect), with concise onboarding copy. Keep the existing unavailable/recovery cards for the non-first-run cases; do not show disabled sign-in buttons in the reachable "connected, no snapshot yet" state (already fixed for Codex — preserve it).
- [ ] **Step 3:** Ensure the first-run action dismisses/opens correctly (browser/CLI flows) and that completing auth transitions the tab to normal content without a host resize (respect the shared content floor).
- [ ] **Step 4:** Keep provider content bounded and non-scrolling. Add a presentation test for the first-run vs unavailable vs recovery decision per provider. Signed-app acceptance of both first-run flows.

## Workstream E — Per-agent quota warnings + real per-agent notifications

**Goal:** Move the "Remaining Quota" threshold controls off the global Notifications page and into each agent's page, backed by a per-provider threshold store, and deliver real notifications for **both** providers (not just Codex).

**Threshold-control design (2026-07-24, from the provided mockup — "Option A1, chip buttons"):** the per-agent "Remaining Quota" control is a row of multi-select **chip buttons** for the thresholds. Reconcile this with the existing `AgentUsageWarningsSection` (which already renders threshold chips) by adopting the mockup's exact styling and copy:
- Section header `REMAINING QUOTA` (all-caps, small, gray); label **"Notify when remaining reaches"**; helper text **"Applies to both the 5-hour and weekly limits."**
- Chips for **50% / 25% / 10% / 5%**, multi-select, each toggling on click; changes saved immediately; default is all-selected.
- Chip spec: height 28pt, 10pt horizontal padding, 8pt corner radius, 8pt spacing. **Selected** = system-blue fill with blue text and a 12pt `checkmark` SF Symbol; **Unselected** = light-gray fill with gray text. Hover/pressed states per the mockup. (This replaces `AgentUsageWarningsSection`'s current `.borderedProminent` provider-tinted chip look; keep the provider tint only if it does not fight the mockup — otherwise use the mockup's blue selected state.)
- Optional validation "at least one threshold" is allowed but not required; a fully-deselected state is permitted (means "no remaining-quota alerts for this agent").
- Reference: the four mockup options (A1 chip buttons default, A2 chip + "All" toggle, A3 compact chips with dividers, A4 icon+chip) — **A1 is the chosen direction**; A2's "All" toggle is a possible convenience add-on to confirm later.

**Files:** `Settings/NotificationSettingsView.swift` (remove the global Remaining Quota section), `Settings/AgentUsageWarningsSection.swift` (restyle to the mockup + reuse), `Settings/CodexAgentSettingsView.swift` + `Settings/ClaudeAgentSettingsView.swift` (host the section), `Settings/AppSettings.swift` (per-provider threshold storage + migration), `Notifications/QuotaNotifier.swift` (provider-scoped alerts), `Monitoring/QuotaMonitor.swift` + `Quota/ClaudeUsageMonitor.swift` (invoke delivery), and notifier/threshold tests.

- [ ] **Step 1:** Add per-provider threshold storage to `AppSettings` (e.g. `enabledQuotaThresholds(for: AgentProvider)`), keyed per provider, **migrating** the existing global `notification.enabledQuotaThresholds` into each active provider's set so no user setting is lost. Keep `alertsEnabled` global (the master permission gate). Add a migration test (old global value → both providers) and per-provider get/set tests.
- [ ] **Step 2:** Restyle `AgentUsageWarningsSection` to the mockup (A1 chip spec, header/label/helper copy, selected/unselected/hover/pressed states), wire it into the Claude page, and repoint both pages' bindings to the provider-scoped store. Remove the "Remaining Quota" section from `NotificationSettingsView`; leave the master toggle, permission status, and non-quota "Other Warnings" there. Update `NotificationSettingsContextView` copy if it references the moved control.
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

## Workstream G — Refresh cadence consistency across all agents

**Goal:** All agents share one refresh-cadence contract, so the user's Refresh Preferences (and the automatic adaptive behavior) apply consistently to every provider instead of only Codex.

**Current inconsistency (grounded 2026-07-24):**
- **Codex** (`Monitoring/QuotaMonitor.swift` + `Monitoring/RefreshSchedule.swift`) uses a rich, user-configurable cadence: `AppSettings.refreshMode` (Automatic / 90s / 2m / 5m / 10m) plus automatic burst/backoff logic (30s burst, 60s low-remaining/exhaustion/reset-verification, 300s normal, 600s idle, 5m failure backoff, 10m interruption backoff).
- **Claude** (`Quota/ClaudeUsageMonitor.swift`) ignores all of that and polls on a **hardcoded `defaultPollInterval = 12 minutes`**. The user's Refresh Preferences never reach Claude, and its cadence does not adapt to low remaining quota or reset windows.
- Result: two providers with divergent freshness behavior and one setting that only governs one of them.

**Design intent:** Make `RefreshSchedule`/`RefreshMode` the shared cadence authority. Each provider monitor keeps ownership of its own read cycle but derives its next interval from the same schedule + the same user setting, so "Automatic" and the fixed modes mean the same thing everywhere. Preserve `ClaudeUsageMonitor` as the sole owner of Claude reads (do not add a second scheduler) and keep the accepted Claude source order (OAuth → statusLine → cache).

**Decision (2026-07-24, confirmed): one shared cadence control for all agents.** A single `refreshMode` governs every provider.

**Claude rate-safety constraint (must resolve before shipping G).** Codex's read is a **local app-server read**, so fast intervals (down to the 30s burst / 60s / 90s modes) are cheap and safe. Claude is different: its authoritative source is an **OAuth read against an Anthropic endpoint**, and polling that as aggressively as Codex risks rate limiting or endpoint/abuse issues. Therefore, one shared *setting* must not mean one shared *network frequency* for Claude:
- **Source-aware cadence.** Frequent ticks should be served from Claude's **local statusLine/cache** where possible; the **networked OAuth read must obey a conservative minimum interval** regardless of the selected mode. The mode still changes how often the UI/local snapshot updates, but the OAuth network call is floored.
- **Establish the safe floor empirically** (see Step 1b) rather than guessing; do not lower it below what the endpoint tolerates. A plausible starting floor is on the order of a few minutes for the network read, but confirm before adopting a number.
- **Back off on 429/anomalies.** If Claude's endpoint returns rate-limit/`429`/transient errors, apply the existing backoff discipline and do not tighten the interval.
- Codex keeps its full fast range because its read is local.

**Files:** `Monitoring/RefreshSchedule.swift` (generalize/share), `Quota/ClaudeUsageMonitor.swift` (adopt the shared cadence instead of a fixed poll), `Monitoring/QuotaMonitor.swift` (unchanged behavior, shared source), `Settings/RefreshSettingsView.swift` + `Settings/RefreshSettingsContextView.swift` (copy: the setting now governs all agents), `Settings/AppSettings.swift` (only if a per-provider floor/override is needed); cadence tests.

- [ ] **Step 1 (decision — confirmed 2026-07-24):** **One shared cadence control** (`refreshMode`) governs every provider. Not per-agent. Claude's *network* frequency is protected by a source-aware floor (below), not by a separate user control.
- [ ] **Step 1b (probe — blocking for Claude):** Determine the safe minimum interval for Claude's networked OAuth read so the shared cadence cannot cause endpoint/rate-limit issues. Inspect any documented/observed Anthropic usage-endpoint limits and the Claude Code client's own polling behavior; run a bounded, consented probe if needed. Record the chosen network floor and its evidence in `docs/development/`. Do not ship G until this floor is set.
- [ ] **Step 2:** Extract the schedule decision so it is provider-agnostic (input: mode, last record/availability, timing signals, **source cost/floor**; output: interval + reason). Keep Codex behavior identical under test.
- [ ] **Step 3:** Have `ClaudeUsageMonitor` derive its cadence from the shared schedule + `refreshMode`, but **clamp the OAuth network read to the Step 1b floor** and prefer local statusLine/cache for sub-floor ticks — replacing the hardcoded `defaultPollInterval` while remaining the single Claude read owner. Preserve immediate-refresh-on-launch and manual "Force a reading" (the consented manual read may bypass the automatic floor but still respects backoff).
- [ ] **Step 4:** Update Refresh Preferences copy to state it governs all agents; ensure the popover/Settings "Updated HH:MM" freshness reads consistently per provider.
- [ ] **Step 5:** Tests: the same `refreshMode` yields the documented interval for both providers (with each provider's floor); automatic mode adapts identically; Codex regression suite unchanged. Signed-app acceptance that changing the setting visibly changes both providers' cadence (record observed/not-run honestly).

---

## Sequencing and dependencies

1. **E (per-agent notifications)**, **C (standardized disconnect)**, and **G (refresh cadence)** touch the deepest owners (`AppSettings`, `QuotaNotifier`, `RefreshSchedule`, the monitors and connection controllers); land them as separate reviewable slices first. G and E both generalize a Codex-only mechanism to all providers, so doing G first can de-risk E's per-provider evaluation cadence.
2. **D (popover first-run)** is a presentation slice that can follow independently. **B (menu readout) is skipped for now** by user direction.
3. **A (README)** and **F (app icon)** are non-code/asset slices; do them last so the README describes the final behavior and the icon reflects the finished product.

Prefer one focused PR per workstream (or per small group) over one omnibus PR, per the evidence-rich-PR guide.

## Decisions (resolved 2026-07-24)

- **B — menu-bar readout:** **skipped for now** by user direction ("don't generate the menubar icons, skip that part"). Format decision is retained for resumption (glyph + percent pairs, one active window per provider — 5-hour default → weekly fallback; stacked variant gated on UI samples), but no B work happens this pass.
- **C — disconnect:** a **standardized disconnect button for all agents**, wired per-provider; Codex disconnect is **app-local only** (leaves CLI session and credential untouched).
- **E — per-agent quota warnings:** thresholds move per-agent with a per-provider store + migration; the chip control follows the provided mockup (**Option A1 chip buttons**: 50/25/10/5% multi-select, 28pt chips, blue selected + checkmark). Non-quota "Other Warnings" stay global.
- **F — app icon:** user will draw the artwork later; this workstream only wires it when it arrives.
- **G — refresh cadence:** **one shared cadence control** governs all agents. Claude's networked OAuth read is protected by a **source-aware minimum floor** (Step 1b probe) so the shared setting cannot cause Anthropic endpoint/rate-limit issues; Codex keeps its full fast range because its read is local. **Open:** the exact Claude network floor value (Step 1b).

## Documentation and acceptance

- Update `docs/product/planning-board.md` (new rows per workstream), the relevant deferred plans (mark superseded scope), `AGENTS.md` (only durable invariants — e.g. provider-scoped notification identity, per-agent threshold store), `how-to.md`, and `UsageProbe/README.md` where user-visible behavior changes.
- Each workstream's PR must separate Run / Observed / Not run evidence and keep the menu-bar popover visual/keyboard/VoiceOver waiver explicit.

## Additional candidate touches (flagged, not committed)

Noticed while grounding this plan; confirm before adding scope:

- First-run onboarding consistency between `ClaudeSetupOnboardingView` and a (currently absent) Codex onboarding equivalent.
- Reconciling the deferred "distinct menu-bar status markers" plan into Workstream B rather than leaving it separate.
- Developer ID signing finalization (previously gated behind "proper popover + per-agent notifications", both of which this plan completes).
