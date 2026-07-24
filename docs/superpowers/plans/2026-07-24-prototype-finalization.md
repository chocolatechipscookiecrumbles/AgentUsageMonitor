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

- [x] **Step 1 (done):** `README.md` created following the reference shape — tagline, product statement, a provider/data-source table with the per-provider privacy boundary, a build/run section (`swift build`, `swift test`, `Scripts/build-app.sh`), a feature tour, and a durable-docs index.
- [x] **Step 2 (done):** Compact architecture note (owners `QuotaViewModel`, `QuotaMonitor`/`ClaudeUsageMonitor`, `QuotaNotifier`), plus an explicit personal, non-commercial scope and the Anthropic ToS caveat. All cross-links verified to resolve.
- [ ] **Step 3:** Verify links resolve and no build/verification claim is asserted as observed unless it was run.

## Workstream B — Multi-provider menu-bar readout — RESUMED & IMPLEMENTED (2026-07-24)

**Status: implemented under a dedicated approved plan** ([menu-bar graphical indicators](2026-07-24-menu-bar-graphical-indicators.md)). The user supplied UI samples and approved **"Bars"** (four stacked bars) and **"Combined"** (weekly background + five-hour inset). After trying the modes, the selector was trimmed (2026-07-24): the **Gauge** text mode and the experimental **Single Provider** bar mode were removed, and the default is now **Combined**. The remaining Style options are **"5-hour and weekly"** (text, now showing both Codex windows again), **"Bars"**, and **"Combined"**. Graphical track width was tuned to 40 points. Source + unit/geometry/accessibility tests are complete (272 passing); signed-app visual validation of the bar rendering remains (waiver). The earlier single-active-window "glyph + percent" design below is **superseded**.

> **SUPERSEDED — do not implement.** The following goal/decision/steps described the original "glyph + percent pair" concept, which the approved bar modes replaced. Retained only for provenance.

**Goal (superseded):** The menu-bar item shows usage for **both** connected providers at a glance — one glyph + percent per provider — while degrading cleanly to one provider or the unavailable label.

**Decision (superseded):**
- Format is **glyph + percent pairs**, one pair per available provider.
- Each provider contributes a **single "active window" percent** (5-hour default, weekly fallback).
- A stacked per-provider variant was gated on UI samples — those samples produced the approved bar modes instead.

*(Original Steps 0–5 for the glyph+percent approach removed as superseded; the bar modes were implemented under the dedicated plan.)*

## Workstream C — Standardized Connect/Disconnect for every agent

**Goal:** A **single, standardized Disconnect control** (shared component with consistent label, placement, confirmation, and disabled rules) used on every agent page, **wired per-provider** to each provider's own disconnect mechanism. Replaces the Codex disconnect stub and de-duplicates the two hand-rolled connection-action blocks.

**Design (2026-07-24):** The disconnect button is the same reusable view for all agents — one visual/interaction contract. What differs per provider is only the injected action and the "what this touches" guidance, because each provider is connected differently (Codex via browser/CLI session; Claude via the Keychain credential read). The component takes a provider tint, a disconnect closure, an enabled/confirmation policy, and provider-specific guidance copy. Connect affordances stay provider-specific (Codex browser+CLI vs Claude Keychain) since those genuinely differ, but the **Disconnect** affordance is unified.

**Files:** Create a shared `Settings/AgentDisconnectButton.swift` (standardized control); `Settings/CodexAgentSettingsView.swift` and `Settings/ClaudeAgentSettingsView.swift` (adopt it); `Connection/CodexConnectionController.swift` (owner of Codex connection state); `Menu/QuotaViewModel.swift` (expose `disconnectCodex`, mirroring `disconnectClaude`).

- [x] **Step 1 (decision — confirmed 2026-07-24):** Codex disconnect is **app-local only** — hides Codex usage and stops auto-detecting, leaving the Codex CLI session and stored credential untouched.
- [x] **Step 2 (done):** `AppSettings.codexDisconnected` (persisted) + `CodexConnectionController.disconnect()` (stops the watcher/activation observer, no auto-reconnect; `start()` respects a persisted disconnect; `checkConnection`/sign-in clear it) + `QuotaMonitor` gate (blanks usage to an explicit disconnected state, resumes on reconnect) + `QuotaViewModel.disconnectCodex()`. Tests: disconnect persists + stays disconnected, persisted disconnect respected at start, reconnect clears the flag.
- [x] **Step 3 (done):** `AgentDisconnectButton` — one shared destructive control with a confirmation dialog whose copy reassures that the provider's own login/credential is untouched; only the provider name and injected action differ. Shown only when connected.
- [x] **Step 4 (done):** Adopted on both pages — Codex wired to `disconnectCodex` (replacing the disabled stub and its "Disconnect is planned" copy), Claude wired to its existing `disconnect`. Codex connected-guidance copy updated.
- [~] **Step 5 (not run):** Signed-app connect/disconnect/reconnect acceptance on both pages — pending a signed build (record honestly). Automated coverage proves the connection-state transitions; the visual/interaction pass is unobserved under the branch waiver.

## Workstream D — Popover first-run authentication state

**Goal:** When a provider has never been set up, its popover tab shows a clear "authenticate to get started" state that reuses the existing sign-in affordances — Codex browser + CLI, Claude Keychain — distinct from the transient "connected, no snapshot yet" state.

**Status (2026-07-24): already satisfied by the shipped popover — no new code needed.** Verified on inspection during finalization:

- `Menu/CodexMenuContent.swift` falls back to `CodexUnavailableContent` when there is no presentation; that card shows `CodexSignInActions` (browser + CLI) for `.disconnected`/`.missingCLI`/`.failed`, and **suppresses** them for `.connected` (points at Refresh Now instead).
- `Menu/ClaudeMenuContent.swift` falls back to `ClaudeUnavailableContent` when no model is available; that card shows `ClaudeCredentialActions` ("Use Claude Code credentials…") for `.notConnected`/`.missingCLI`/`.failed`, and suppresses it for `.connected`. Passive capture (a merely-not-connected but readable account) is treated as normal, not first-run.
- The C-workstream app-local disconnect flows straight through these: disconnecting a provider makes its usage unavailable, so the popover shows the same authenticate-to-reconnect card.
- The "connected, no snapshot yet" distinction (Step 2's requirement) is already the `.connected` branch of both cards, which does not render disabled sign-in buttons.

Remaining (unobserved under the branch waiver): signed-app acceptance that completing auth from the popover transitions the tab to normal content without a host resize. No source change is warranted; if a genuine first-run vs app-local-disconnect **copy** distinction is later desired (e.g. "disconnected" vs "isn't connected"), that is a small polish, not a structural gap.

## Workstream E — Per-agent quota warnings + real per-agent notifications

**Goal:** Move the "Remaining Quota" threshold controls off the global Notifications page and into each agent's page, backed by a per-provider threshold store, and deliver real notifications for **both** providers (not just Codex).

**Threshold-control design (2026-07-24, from the provided mockup — "Option A1, chip buttons"):** the per-agent "Remaining Quota" control is a row of multi-select **chip buttons** for the thresholds. Reconcile this with the existing `AgentUsageWarningsSection` (which already renders threshold chips) by adopting the mockup's exact styling and copy:
- Section header `REMAINING QUOTA` (all-caps, small, gray); label **"Notify when remaining reaches"**; helper text **"Applies to both the 5-hour and weekly limits."**
- Chips for **50% / 25% / 10% / 5%**, multi-select, each toggling on click; changes saved immediately; default is all-selected.
- Chip spec: height 28pt, 10pt horizontal padding, 8pt corner radius, 8pt spacing. **Selected** = system-blue fill with blue text and a 12pt `checkmark` SF Symbol; **Unselected** = light-gray fill with gray text. Hover/pressed states per the mockup. (This replaces `AgentUsageWarningsSection`'s current `.borderedProminent` provider-tinted chip look; keep the provider tint only if it does not fight the mockup — otherwise use the mockup's blue selected state.)
- Optional validation "at least one threshold" is allowed but not required; a fully-deselected state is permitted (means "no remaining-quota alerts for this agent").
- Reference: the four mockup options (A1 chip buttons default, A2 chip + "All" toggle, A3 compact chips with dividers, A4 icon+chip) — **A1 is the chosen direction**; A2's "All" toggle is a possible convenience add-on to confirm later.

**Files:** `Settings/NotificationSettingsView.swift` (remove the global Remaining Quota section), `Settings/AgentUsageWarningsSection.swift` (restyle to the mockup + reuse), `Settings/CodexAgentSettingsView.swift` + `Settings/ClaudeAgentSettingsView.swift` (host the section), `Settings/AppSettings.swift` (per-provider threshold storage + migration), `Notifications/QuotaNotifier.swift` (provider-scoped alerts), `Monitoring/QuotaMonitor.swift` + `Quota/ClaudeUsageMonitor.swift` (invoke delivery), and notifier/threshold tests.

- [x] **Step 1 (done):** `AppSettings` now stores thresholds per provider (`enabledQuotaThresholdsByProvider`, keyed `notification.enabledQuotaThresholds.<provider>`) with `isQuotaThresholdEnabled(_:for:)` / `setQuotaThreshold(_:enabled:for:)`. Migrates the old global set (and the oldest boolean) into every supported provider. `alertsEnabled` stays global. Tests cover independence/persistence and both migration paths.
- [x] **Step 2 (done):** `AgentUsageWarningsSection` restyled to the A1 chip mockup, wired into the Claude page, both pages repointed to the provider-scoped store. Removed the global "Remaining Quota" section from `NotificationSettingsView`; kept the master toggle and Other Warnings. `NotificationSettingsContextView` preview now reads across providers. **Follow-up fix (re-render):** the first cut passed threshold state through plain closures, so the chips sat in a subtree that did not observe `AppSettings` and a tap showed only a press animation. Adding `@ObservedObject` to the leaf section was not enough — `AgentSettingsPageTemplate` captures its content once in `init`, freezing the subtree — so `AgentsSettingsView` (the container the template is built in) now also observes `AppSettings`, which rebuilds the page on any threshold change (the same thing a tab switch did). Chips use an unmistakable state: solid accent fill + checkmark when on, gray outline + plus when off.

**Follow-up feature (confirmation notification):** enabling one or more thresholds now delivers a confirmation like "Will warn you when Claude reaches 25%." Toggles within a 3-second window are debounced and summarized into one message ("Will warn you when Codex reaches 25% and Claude reaches 10%."); a threshold enabled then disabled in the window cancels out. Built from a pure `ThresholdConfirmationMessage.body(for:)` (tested) plus a debounce in `QuotaViewModel` that watches `enabledQuotaThresholdsByProvider`; delivered via a non-deduplicated `QuotaNotifier.deliverConfirmation` gated on `alertsEnabled` (chips are only interactive when alerts are on).
- [x] **Step 2b (decision — confirmed 2026-07-24):** The non-quota "Other Warnings" (forecast, reset, stale, refresh-failure) **stay global** on the Notifications page. Only the remaining-quota thresholds move per-agent.
- [x] **Step 3 (done):** Extracted `QuotaThresholdEvaluator` (pure, testable) shared by both providers: provider-scoped thresholds, provider-named titles, and dedup keys that **keep Codex's original provider-less key** while namespacing Claude, so no already-notified Codex episode re-fires. `QuotaNotifier` delivers via it.
- [x] **Step 4 (done):** Claude delivery added via a second `QuotaNotifier` instance owned by `QuotaViewModel` (same `.app` gate, shared authorization + UserDefaults dedup, so no double-fire). It evaluates only on a **live** Claude read (cached reads do not re-alert). `QuotaMonitor` remains Codex's caller; no second scheduler was added.
- [~] **Step 5 (partial):** `QuotaThresholdEvaluatorTests` (fires once per crossed enabled threshold; real zero alerts, missing window does not; no-reset window skipped; disabled excluded; Codex legacy vs Claude namespaced key; provider-named titles) plus the Step 1 migration tests. Full suite 246 passing. **Not run:** signed-app acceptance of a real per-provider delivery — pending a signed build (record honestly).

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

- [x] **Step 1 (decision — confirmed 2026-07-24):** **One shared cadence control** (`refreshMode`) governs every provider. Not per-agent. Claude's *network* frequency is protected by a source-aware floor (below), not by a separate user control.
- [~] **Step 1b (probe — conservative floor adopted; full probe still open):** Claude's networked OAuth read is floored at **5 minutes** (`ClaudeRefreshCadence.networkFloor`) — at most 12 reads/hour, well clear of any reasonable endpoint limit. This conservative default is documented in code with reasoning; a dedicated evidence-gathering probe (observed Anthropic limits / Claude Code's own polling) may later justify lowering it, but the shipped value is safe now.
- [ ] **Step 2 (deferred — not required for safety):** Full provider-agnostic extraction of the adaptive burst policy. Not done in this slice and not needed for Claude: because Claude's network read is floored, the Codex-only burst/backoff (which drops to 30s/60s) would be clamped away anyway. Claude uses a floored mode→interval mapping (`ClaudeRefreshCadence`) instead of the full adaptive policy, by design. Revisit only if Claude should adapt within the safe band.
- [x] **Step 3 (done):** `ClaudeUsageMonitor` now derives its cadence from the shared `refreshMode` via `ClaudeRefreshCadence`, clamped to the network floor, re-read each tick so a live setting change takes effect without restart. The hardcoded 12-minute production poll is replaced (the constant remains only as the fixed-init fallback for tests). Immediate-refresh-on-launch and manual "Force a reading" are preserved.
- [x] **Step 4 (done):** Refresh Preferences copy states the interval governs every agent and that Claude's automatic refresh never goes faster than 5 minutes to stay within Anthropic's limits.
- [~] **Step 5 (partial):** Added `ClaudeRefreshCadenceTests` (sub-floor clamp, at/above-floor passthrough, automatic→floor, no-mode-below-floor); Codex regression suite unchanged; full suite 237 passing. **Not run:** signed-app acceptance that changing the setting visibly changes Claude's cadence — pending a signed build (record honestly).

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
