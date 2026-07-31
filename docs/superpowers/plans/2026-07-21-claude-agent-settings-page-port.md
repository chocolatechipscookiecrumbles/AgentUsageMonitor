# Claude Agent Settings Page — Template Port Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static `ClaudeCodePreviewSettingsView` with a real `ClaudeAgentSettingsView` that ports the **existing Codex agent-page template** — the same `SettingsSection` / `AgentQuotaSessionSection` / `AgentUsageWarningsSection` composition `CodexAgentSettingsView` already uses — adapted to Claude's data model, matching the pixel spec in the historical untracked `High-fidelity macOS menu UI v6 agent view update/src/components/AgentsSection.tsx` Figma download. Most of the template is already provider-neutral and transfers directly; this plan is about the *visual* port, wiring the small set of Claude-specific adaptations onto the shared components.

## Relationship to the wiring plan (read first)

This plan is the **UI half**; its data comes from the [Claude Usage Provider Wiring plan](2026-07-21-claude-usage-provider-wiring.md), which reconciles `ClaudeUsageMonitor` to drive `ClaudeUsageCollector` and exposes a `ClaudeUsageDisplayModel`. **This plan supersedes and refines that plan's Task 4** (the placeholder `ClaudeUsageStatusView` sketch): build the full template-faithful `ClaudeAgentSettingsView` here instead. Land the wiring plan's Tasks 1–3 (prompt policy, monitor↔collector reconciliation, display-model mapper) first, or stub `ClaudeUsageDisplayModel` so this page can be built and tested against fixtures in parallel.

---

## The existing template (what we port from)

Two sources describe the same page. The **Swift components are the shipped source of truth** for dimensions; the **Figma is the design reference** for element choice, placement, and states the Swift page doesn't yet cover.

### A. Swift template — already built, already provider-neutral

The Codex page is assembled in [CodexAgentSettingsView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift) from these reusable pieces, most already parameterized by `AgentProvider`:

| Component | Role | Provider-neutral today? |
| --- | --- | --- |
| `AgentSettingsPageTemplate` | page shell wrapping `SettingsPage` | ✅ yes |
| `AgentSettingsTabStrip` + `AgentSettingsIcon` + `AgentSettingsCatalog` | the header tab row (Codex · Claude · Copilot) | ✅ already renders a **Claude** tab |
| `SettingsSection` / `SettingsSectionRow` / `SettingsPreferenceControlRow` / `SettingsDescription` | grouped-card primitives | ✅ yes |
| `AgentQuotaSessionSection` → `AgentQuotaWindowRow` → `ProviderQuotaProgressBar` | the "Current quota" card + windows + bars | ✅ takes `provider:`; **but** hard-codes a Credits row + `AgentResetCreditsRow` |
| `AgentUsageWarningsSection` | threshold chips | ✅ takes `provider:` (tint follows `provider.settingsPresentationTint`) |
| `AgentProvider.claudeCode` | title "Claude Code", tab "Claude", asset "Claude", tint `.orange`, `systemImage "terminal"` | ✅ already exists |

The tab strip **already includes Claude** — [AgentsSettingsView.swift:23](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift#L23) just routes `.claudeCode` to the static preview. Only the page *interior* is new work.

### B. Figma v6 reference — `AgentsSection.tsx`

The historical untracked download's `CodexAgentPage` is the detailed target: four grouped cards — **Connection**, **Current Quota**, **Usage Warnings**, **Privacy** — built from `PrefGroupInline` (the rounded-10 card) and `InfoRow` (label/value). Note its `ClaudeAgentPage` is the **old "not connected / planned" placeholder** (a centered hero card + Requirements list); **do not port that** — Claude now has real data, so it gets the Codex page's rich structure. Use the Figma's Claude page only for the *unavailable/onboarding* fallback styling (the centered icon-badge + primary button pattern, Claude orange `#D97757`).

### C. Dimensions reference (Swift `SettingsLayoutMetrics` governs; Figma values in parentheses)

| Element | Swift metric | Value | Figma (Tailwind) |
| --- | --- | --- | --- |
| Settings page interior width | `settingsPageWidth` = 680 − 180 − 1 | **499 pt** | — |
| Page header height | `pageHeaderHeight` | 52 | (`py-3` tabs) |
| Tab item width / icon slot / artwork | `agentHeaderTabWidth` / `agentHeaderIconSlotSize` / `…ArtworkMaxSize` | 132 / 20 / 16 | (icon 17px, name 13px medium) |
| Selected-tab underline | `agentHeaderUnderlineWidth` × `Height`, tint = provider tint | 96 × 2 | (`#0a84ff`, 2px — Swift uses provider tint instead) |
| Inter-tab divider | `dividerWidth` × `agentHeaderDividerHeight` | 1 × 22 | (1px) |
| Section corner radius | `sectionCornerRadius` | 10 | (`rounded-[10px]`) |
| Section content horizontal padding | `sectionContentHorizontalPadding` | 14 | (`px-4` = 16) |
| Section row vertical padding | `sectionRowVerticalPadding` | 12 | (`py-[9px]`) |
| Quota progress bar height | `agentQuotaProgressBarHeight` | **6** | (`h-[3px]` — keep Swift's 6) |
| Warning chip width / spacing | `agentWarningChipWidth` / `agentWarningChipSpacing` | 46 / 8 | (`px-2.5 py-1`, `gap-1.5`) |
| Row label / control column | `labelWidth` / `controlWidth` | 148 / 190 | — |
| Section spacing / page padding | `regularSectionSpacing` / `regularPageHorizontalPadding` | 20 / 20 | (`mb-4`, `px-5`) |
| Compact breakpoint | `compactWidthBreakpoint` | 500 | — |

Palette anchors (from Figma, for status accents the Swift palette must supply): connected/OK green `#30d158`, warning amber `#ff9f0a`, error red `#ff453a`, action blue `#0a84ff`, **Claude orange `#D97757`**.

### D. Provider-color & window-opacity convention (documented — must carry over)

This is a **first-class, already-documented rule**, not a per-page choice. Per the [Codex-first Agents Settings UI plan](2026-07-19-codex-first-agents-settings-ui.md) (lines 52, 61, 67):

1. **One provider tint, one source.** `AgentProvider.settingsPresentationTint` is the single color source for the **selected-tab underline, both quota-bar hues, the usage-warning chips, and the Context Rail status treatment**. Codex is `#576DFF`. *"Future providers must add their color once and use the shared components rather than hard-coding colors."* → Claude adds its color **once**; it must never appear as a literal in any view.
2. **Five-hour vs. weekly differ by opacity, not hue.** `AgentQuotaWindowKind` owns *"the only allowed foreground opacity: five-hour is `1`, weekly is `0.72`,"* letting the weekly bar composite with the Light/Dark card surface to read as the subdued sibling — **no second hue, no blend mode, no native progress style** (`ProviderQuotaProgressBar` is a palette track + a `Capsule` filled with the raw tint).

**Consequence for this port — mostly free, one real fix:** because `ClaudeAgentSettingsView` reuses `AgentSettingsTabStrip`, `AgentQuotaWindowRow`/`ProviderQuotaProgressBar`, `AgentUsageWarningsSection`, and the Context Rail card, Claude **inherits the underline, both bar tints, the chip tint, and the 1.0/0.72 window differentiation automatically** — provided its tint is correct. The gap: `AgentProvider.claudeCode.settingsPresentationTint` is currently the generic system `.orange`, not the brand color. It must be set **once** to the exact Claude orange `#D97757` = `Color(red: 217/255, green: 119/255, blue: 87/255)` (mirroring how Codex encodes `#576DFF`). No opacity or per-window color work is needed beyond that — the shared components already encode it.

### E. Full 7/19 provider-page presentation contract (all of it, not just tint/opacity)

The 7/19 plan (lines 42–53) states a **binding contract for "every provider page that later has a sanitized quota presentation."** This port must satisfy all of it:

| Contract rule (7/19) | This port |
| --- | --- |
| Must use `AgentSettingsPageTemplate`, `AgentQuotaSessionSection`, `AgentQuotaWindowRow`, `AgentQuotaWindowKind`, `AgentSettingsIcon`, `ProviderQuotaProgressBar`; no per-page icon sizing, horizon-bar color, or alignment offsets | ✅ reuses all; adds only composability flags |
| **No boilerplate Privacy section on a provider page** — privacy inventory/policy lives only in the app-wide **Data & Privacy** destination; new provider data is documented separately before exposure | ⚠️ **corrected** — the Claude page has *no* Privacy card; Claude's OAuth/Keychain/statusLine/cache data is documented in Data & Privacy (Task 5) |
| Connection/quota facts use `SettingsPreferenceControlRow` (right-aligned value column, correct below the 500 pt compact breakpoint); **Plan belongs in Connection, not Current quota** | ✅ Source section uses `SettingsPreferenceControlRow`; plan hint sits in Source, not the quota card |
| Current quota always reserves 5-Hour + Weekly; a missing window renders an explicit unavailable/idle state (not a removed row); tint only on a real value | ✅ inherited from `AgentQuotaWindowRow` |
| `Quota status` absent from Current quota; connection/source state stays in its own section | ✅ |
| `QuotaValueMode` (Remaining/Used) from General drives both windows; reset time supplemental | ✅ Task 2 |
| One selector only (`AgentSettingsTabStrip`); providers enter via the **display catalog**, not a custom header | ✅ — requires flipping the catalog entry `.preview → .supported` (Task 3 Step 1) |
| Context Rail uses the **catalog icon** in its shared smaller slot, never an SF Symbol fallback where an asset exists | ⚠️ **corrected** — Task 4 uses `AgentSettingsIcon`, not `provider.systemImage` |
| Usage-warning chips carry read/write closures for a future per-provider scoped store; a non-interactive provider's chips stay inert | ✅ Task 3 — Claude chips disabled until the per-provider/window store lands ([followups Task 3](2026-07-14-settings-provider-followups.md)) |
| **Don't add broad tests for visual work**; add a narrow deterministic regression test only for a state→view routing defect, and rely on **signed-app visual acceptance** | ⚠️ **corrected** — unit tests only for pure logic (tint, adapter, display-model, routing); the view is verified by the signed-app acceptance matrix, not broad view tests |
| Deferred disconnect may be a disabled control with plain copy | n/a for Claude (no sign-in / no disconnect) |

---

## Codex → Claude mapping (what transfers vs. what changes)

| Codex section | Claude section | Change |
| --- | --- | --- |
| **Connection** (Status pill, App Server path, Protocol, version, Connect/Disconnect, browser/CLI sign-in) | **Source** | Claude reuses Claude Code's *own* credential — there is **no sign-in flow**. Replace with: active source label (Claude OAuth / Claude Code capture / Cached), plan hint (`subscriptionType`), relative capture time, delivery/freshness note, and a **Refresh Claude Usage** button. Onboarding/unavailable variant when no source (use Figma Claude hero styling). |
| **Current Quota** (Plan, 5-hour bar, Weekly bar, **Credit Balance**, **Reset Credits**, Last confirmed) | **Current Quota** | Reuse `AgentQuotaWindowRow` for 5-hour + weekly via a `ClaudeLimitWindow → QuotaWindow` adapter. **Omit Credits + Earned Reset Credits** (Claude has neither). Add the **shared-pool caveat** under the weekly row (gate #3). Optionally add scoped rows (Sonnet/Opus weekly, `limits[]`) and an **extra-usage/spend** row (Claude-only, from `ClaudeExtraUsage`). |
| **Usage Warnings** (threshold chips) | **Usage Warnings** | Reuse `AgentUsageWarningsSection(provider: .claudeCode)` verbatim (tint auto-becomes orange). **But** Claude alerts aren't wired to a notification pipeline yet → render disabled with a "planned" note, or defer this section (see Deferred). |
| **Privacy** (Figma shows a Privacy card) | **— omitted** | The shipped Codex page has **no** Privacy section — the 7/19 contract routes all privacy inventory/policy to the app-wide **Data & Privacy** destination. Claude follows suit: **no provider-page Privacy card.** Claude's new data (OAuth Keychain read, statusLine snapshot, cache) is documented in Data & Privacy instead (Task 5). The one privacy-adjacent fact that belongs on the quota card — the weekly number may be **shared with Claude chat/Cowork** — rides as the weekly footnote, not a section. |

The tab strip, page shell, section cards, progress bars, and warning chips transfer with **zero structural change** — this is the "mostly transferable" core. (Note: the Figma's four-card Codex page includes a Privacy card, but the *shipped* Codex Swift page deliberately dropped it per the contract; follow the shipped page, not the Figma, here.)

---

## Global constraints

- **Dimensions come from `SettingsLayoutMetrics`, not literal Figma px** — the shipped Codex page is the visual baseline this must sit beside; the Figma resolves *which* elements and *where*, not exact sizes (keep the 6 pt bar, the 132 pt tab, etc.).
- **No new stored state, no secrets in the view** — the page binds only to the already-sanitized `ClaudeUsageDisplayModel`; it never touches tokens, raw snapshots, or Keychain directly.
- **Never present stale/expired as live** (gate #5): cached/expired windows are visibly labeled; no zeroed bars pretending to be a real reading.
- **Reuse over fork:** extend the shared provider-neutral components with options rather than cloning them, preserving the codebase's stated "reusable … for a provider" intent. Codex's rendering must be byte-for-byte unchanged after any shared-component edit.
- **Provider color is added once, never hard-coded** (see section D): the tab underline, both quota bars, warning chips, and rail treatment all derive from `AgentProvider.claudeCode.settingsPresentationTint`; the five-hour/weekly distinction stays the shared `1.0`/`0.72` opacity composite. No literal Claude color, no per-window hue, no alternate bar style may appear in `ClaudeAgentSettingsView`.
- **No provider-page Privacy section** (7/19 contract, section E): privacy inventory/policy stays in the app-wide Data & Privacy destination; do not add a Privacy card to `ClaudeAgentSettingsView`.
- **Factual rows use `SettingsPreferenceControlRow`**, not `SettingsLabeledRow`, so Status/Plan/source/capture-time stay right-aligned below the 500 pt compact breakpoint (the page sits one point under it).
- **Testing follows the 7/19 rule for visual work:** narrow, deterministic unit tests only for *pure logic* — the tint constant, the `ClaudeLimitWindow → QuotaWindow` adapter, the display-model mapping, and `.claudeCode` state→view routing. Do **not** add broad view-snapshot tests. The view is verified by the signed-app visual acceptance matrix (see Completion criteria). Each task still ends green on `swift test --filter Claude` against the 44-test baseline.

---

## Status as of 2026-07-23

This plan's checkboxes were never ticked while the page was built across the wiring, connection-state, and layout-fix branches. Reconciled below against the shipped code; the boxes now reflect the source, not the plan's original sequence.

**Done:** Task 1 (in a different shape — see below), Task 2, Task 3 Steps 1/2/2b/3/5/6, Task 4, and Task 5. The first-run state and Claude tint passed user visual acceptance on 2026-07-23. The proposed routing-presence test was explicitly waived because repository policy now permits only defect-driven regression tests.

**Task 1 shipped differently and deliberately.** `AgentQuotaSessionSection` took `creditsLabel` / `creditsValue` / optional `resetCredits` / `weeklyFootnote` / `fiveHourNote` rather than `showsCredits` / `showsResetCredits` booleans, because Claude *does* have a credits figure — Anthropic reports spend beyond the plan where Codex reports a balance held. Parameterizing the label keeps a spend figure from ever appearing under a balance label, which a boolean flag would not have done. No dedicated `AgentQuotaSessionSectionTests` exists; the composition is covered only through `ClaudeUsageDisplayModelTests` and the Codex call site compiling unchanged.

**Disposition of the previously open items:**

1. **Task 3 Step 2b visual acceptance: PASSED 2026-07-23.** The user inspected the first-run card in Light and Dark with the Context Rail hidden and visible and accepted it.
2. ~~**Task 3 Step 4 — Usage Warnings section.**~~ **Deferred by decision 2026-07-23** — it ships with the general notification-settings port, not as a Claude-specific stub. See that step.
3. **Task 3 Step 5 — routing implementation complete; routing test waived 2026-07-23.** `.claudeCode` routes directly to `ClaudeAgentSettingsView` and `ClaudeCodePreviewSettingsView` is deleted. The user directed that future automated coverage be limited to reproducible defect regressions, so a feature-presence routing test will not be added.
4. **Task 5 Step 4 — factual page and Claude tint visual acceptance: PASSED 2026-07-23** (user inspection; layout evidence recorded in the [layout-fixes matrix](2026-07-23-claude-settings-layout-fixes.md#verification-matrix)). The user subsequently inspected the `#D97757` treatment across the five-hour and weekly quota bars and accepted the update. Gate criterion #3 is closed by Anthropic's direct Pro/Max shared-limit documentation.
5. **Developer ID signing: explicitly deferred 2026-07-23.** Functional and visual acceptance may continue on the locally assembled/ad-hoc-verified app. Repairing the local Developer ID identity is deferred until per-agent notifications and the proper menu-bar popover are implemented, before final release signing and permission acceptance.

## Task 1: Make `AgentQuotaSessionSection` composable for providers without credits

- [ ] **Step 1: Write failing tests** (`AgentQuotaSessionSectionTests.swift` or a snapshot-of-inputs test): the section can be built with `showsCredits: false` and `showsResetCredits: false` and an optional `weeklyFootnote`, and that Codex's existing call site (defaults `true`) is unchanged.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Add `showsCredits: Bool = true`, `showsResetCredits: Bool = true`, and `weeklyFootnote: String? = nil` parameters to `AgentQuotaSessionSection`. Gate the Credits `SettingsSectionRow` and the `AgentResetCreditsRow` behind those flags; render `weeklyFootnote` as a `SettingsDescription` under the weekly `AgentQuotaWindowRow`. Codex passes nothing (unchanged).
- [ ] **Step 4: Run to verify they pass; confirm Codex call site compiles unchanged. Commit.**

## Task 2: Adapt Claude windows into the shared quota row

- [x] **Step 0: Set Claude's one provider tint.** Change `AgentProvider.claudeCode.settingsPresentationTint` from `.orange` to the exact brand `Color(red: 217/255, green: 119/255, blue: 87/255)` (`#D97757`), mirroring Codex's `#576DFF` literal. Add a test asserting the value. This one change gives the tab underline, both quota bars, warning chips, and rail treatment the correct color via the shared components (section D) — verify nothing else hard-codes a Claude color.
- [x] **Step 1: Write failing tests** for a `QuotaWindow`-adapter that maps `ClaudeLimitWindow(usedPercent:resetsAt:)` into the exact `QuotaWindow` shape `AgentQuotaWindowRow` consumes (confirm `QuotaWindow`'s initializer/fields first), including the value-mode semantics (Claude reports **used %**; ensure "% used" vs "% remaining" renders correctly for the chosen `QuotaValueMode`).
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** the adapter (a small pure function or `ClaudeUsageDisplayModel` computed property). Map five-hour + weekly; expose scoped windows (`ClaudeScopedLimitWindow`) and `ClaudeExtraUsage` as optional display rows.
- [x] **Step 4: Run to verify they pass. Commit.**

## Task 3: Build `ClaudeAgentSettingsView`

Compose the page from the shared primitives, matching the **shipped Codex page's** section set — Source (Connection-equivalent) + Current quota + Usage Warnings. **No Privacy card** (section E).

- [x] **Step 1: Promote Claude from preview to supported.** In `AgentSettingsCatalog`, change the `.claudeCode` entry's availability from `.preview` to `.supported`, and remove any "Preview" / "Not available yet" labeling that keyed off preview availability for Claude (page and Context Rail). This is how a provider "enters the selector" per the contract — via the catalog, not a custom header. Add a narrow test asserting the catalog marks `.claudeCode` supported.
- [x] **Step 2b: First-run "not set up" state — implemented and visually accepted 2026-07-23.** The user confirmed this is a real, distinct state, not a nicety. Previously every unconfigured case collapsed into the same plain "Not available" / "Not connected" text rows, which was right for a user who *had* a connection and lost it, and wrong for a user who had never set anything up.

  **The distinction to build:**
  - **Never set up** (no app-owned setup history, cached reading, or statusLine snapshot) → the centered treatment: Claude icon badge at low tint opacity (~44pt, rounded), a sentence naming the two working ways in — connect with Claude Code's own credentials, or use passive status-line capture — and a primary credentials button. Browser sign-in was superseded by the later shelved/unverified decision and must not be presented as working.
  - **Set up but not currently connected** (a credential existed, or a cached/stale reading exists) → today's factual rows, unchanged. This user does not need to be re-onboarded; they need the status and a Refresh.

  **Implemented signal:** `ClaudeSetupState.resolve` is the pure, tested decision boundary. Onboarding requires completed initial source discovery, `.notConnected`, unavailable usage, and no persisted setup history. Existing app-owned cache/statusLine files migrate older builds to durable history; any new reading or successful connection records the monotonic `claude.hasSetupHistory` preference. Later disconnect, cache loss, or refresh failure does not erase it. In-progress and failed connection states stay on the factual page so their guidance remains visible. The first-run view names the two working paths—Claude Code credentials and passive status-line capture—and repeats the Keychain disclosure before its primary credentials action. Browser sign-in remains shelved and is not presented as working.
- [x] **Step 2: "Source" section** (`SettingsSection("Source")`): factual rows via **`SettingsPreferenceControlRow`** — active source label, plan hint (`subscriptionType`), relative capture time + delivery/freshness note — plus a `Refresh Claude Usage` button (monitor's user-initiated refresh). Unavailable variant: centered icon badge (Claude tint at low opacity, ~44 pt, rounded) + guidance worded for the real "sign in through Claude Code / enable passive capture" path (not "planned"), reusing the Figma Claude hero styling.
- [x] **Step 3: "Current quota" section**: `AgentQuotaSessionSection(provider: .claudeCode, presentation: <adapted>, valueMode:, showsCredits: false, showsResetCredits: false, weeklyFootnote: <shared-pool caveat>)`. Append scoped/extra-usage rows when present. **No Plan row here** — Plan lives in Source.
- [~] **Step 4: "Usage Warnings" section — DEFERRED BY DECISION 2026-07-23, do not build.** The plan offered two options (inert disabled section, or defer); the user chose defer. **Reason:** an inert section costs vertical space on a page the 2026-07-23 layout pass had just compacted, and tells the user nothing they can act on. **What happens instead:** Claude's warning chips arrive when the *general* notification/threshold settings are ported over, as part of that work rather than as a Claude-specific stub. Whoever does that port owns three things this step would otherwise have covered: the per-provider/window threshold store ([followups Task 3](2026-07-14-settings-provider-followups.md)), wiring Claude thresholds to a real notifier, and adding `AgentUsageWarningsSection(provider: .claudeCode, …)` to the page. Until then the Claude page has no Usage Warnings card at all, and the capability gate correctly records that there are no Claude notifications.
- [x] **Step 5:** Route `.claudeCode` in [AgentsSettingsView.swift:23](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift#L23) to `ClaudeAgentSettingsView(...)`, driven by `QuotaViewModel`'s Claude state, and delete `ClaudeCodePreviewSettingsView`. **Test disposition:** the proposed feature-presence routing test was waived by user direction on 2026-07-23; future automated additions are limited to reproducible defect regressions.
- [x] **Step 6:** Run the full Swift suite. **Commit.**

## Task 4: Claude Context Rail card (catalog icon, real source)

`AgentConnectionsContextView` currently renders Claude as a static preview card; replace it with a factual card mirroring the Codex rail card and the Figma `AgentsContextPanel` "paired" card.

- [x] **Step 1:** Render the Claude card with `AgentSettingsIcon` (the catalog asset in the shared smaller slot — **never** `provider.systemImage`, per the contract), name/subtitle, and a source/freshness value ("Live · OAuth", "Capture · 8m ago", "Cached · 3h ago"). When no source exists, show the unavailable treatment — not a "Preview" label (Claude is no longer a preview entry).
- [x] **Step 2:** Narrow deterministic test for the rail's Claude state→value mapping. **Commit.**

## Task 5: Data & Privacy entry, docs, and bookkeeping

- [x] **Step 1: Document Claude's new provider data in Data & Privacy.** In `DataPrivacySettingsView` / `LocalDataInventory`, record the OAuth Keychain *read* (never stored by this app), the statusLine snapshot file, and the usage cache — since the contract makes Data & Privacy the single home for this and requires new provider data to be documented before exposure. Include the "never reads conversation content" and "weekly number may be shared with Claude chat/Cowork" facts here.
- [x] **Step 2:** Update the [capability research gate](2026-07-20-claude-code-capability-research.md). Gates #3 and #5 are satisfied. Anthropic's Pro/Max-specific help article now directly supports the shared Claude/Claude Code weekly-scope copy.
- [x] **Step 3:** Update the [planning board](../../product/planning-board.md) Claude row and the Agents Settings UI row — both moved to **Verification**, with visual acceptance named as the blocker.
- [x] **Step 4: Signed-app visual acceptance** — **passed 2026-07-23** (user inspection). Observed and unobserved states recorded in the [layout-fixes verification matrix](2026-07-23-claude-settings-layout-fixes.md#verification-matrix).

---

## Deferred (not in this port)

- **Menu-bar Claude quota card** — this plan is Settings-only; the `MenuBarExtra`/`QuotaMenuView` card is a separate follow-up.
- **Claude alert/notification pipeline** — the Usage Warnings chips are display-only until Claude thresholds feed a real notifier.
- **Interactive `statusLine` setup UX** (one-click install + conflict merge) — surfaced from the Source section later; the installer path is only made resolvable in the wiring plan.
- **Scoped/extra-usage rows** may ship as a fast-follow if the first cut keeps parity with Codex's two-window layout.

## Completion criteria

- Selecting the **Claude** tab shows a real, data-driven page using the same shared components and dimensions as the Codex page — **no provider-page Privacy card**; Claude is a `.supported` catalog entry, not a preview.
- Claude-specific differences (credential connection instead of browser sign-in, no credits/reset-credits, weekly shared-pool footnote) render correctly; Claude's privacy data appears in **Data & Privacy**, not the Agents page.
- Codex's page and Context Rail render identically to before (shared-component edits are additive; no Codex behavioral change).
- Unavailable/onboarding, cached/stale, and live states render distinctly; stale is never shown as live.
- The Context Rail Claude card uses the catalog icon and a real source/freshness value.
- **App visual acceptance:** inspect Agents at 680 × 560 pt in Light and Dark, both Context Rail states, with scrolling, keyboard navigation, VoiceOver, and focus preservation; record any unobserved state rather than inferring it. The first-run and tint checks passed on 2026-07-23. Proper Developer ID verification is temporarily deferred until per-agent notifications and the menu-bar popover are complete.
- Existing automated suites remain green; future coverage additions follow the repository's defect-regression-only policy. Docs, Data & Privacy, and the planning board are reconciled.

---

## First-run implementation verification — 2026-07-23

- `swift test` passed **222 tests, 0 failures** after the setup-state, legacy-evidence migration, preference, view-model, and onboarding changes.
- `Scripts/build-app.sh` compiled and assembled the app. This machine's Keychain returned the same Developer ID identity hash hundreds of times; `codesign` returned success but produced an immediately invalid Developer ID signature. Re-signing the unchanged bundle ad hoc passed `codesign --verify --deep --strict`, isolating the failure to local identity state rather than the bundle contents. By user direction, repairing Developer ID signing and verifying permission persistence are deferred until per-agent notifications and the menu-bar popover are complete.
- One separate audit instance was launched without touching the pre-existing user-owned instance. The Settings window opened at the expected **680 × 560-point content size**. macOS Accessibility did not expose the SwiftUI sidebar long enough to navigate to Agents, so automation was stopped per `AGENTS.md`.
- **Observed and accepted by the user, 2026-07-23:** the first-run card in Light and Dark with the Context Rail hidden and visible, plus the `#D97757` differentiation across the five-hour and weekly quota bars.

---

## Handoff — 2026-07-23

**Historical incoming handoff (superseded by the verification block above).** Branch: `feature/claude-connection-state-and-window-copy`. At handoff, the full suite was green at 208 tests and the prior work was committed. The continuation described above remains uncommitted and unpushed; the user opens every PR themselves.

### Where the Claude page stands

It is a real, supported, data-driven page. Selecting the Claude tab shows Connection (status, plan, connect/disconnect), Current quota (both windows, credits-used, weekly scope caveat), Source (what was read and when, with staleness attached), and Force a reading (the consented CLI probe). The rail stacks a Claude card beside Codex. The user inspected the running app on 2026-07-23 and accepted it.

### What changed most recently, and why it matters to you

1. **Claude's tint is now `#D97757`, set once in `AgentProvider.settingsPresentationTint`.** It was system `.orange`. Everything that reads a provider tint — tab underline, both quota bars, warning chips, rail card — changed at once. The user inspected the five-hour and weekly quota-bar treatment on 2026-07-23 and accepted the update.
2. **Claude is `.supported` in `AgentSettingsCatalog`, not `.preview`.** That entry is how a provider "enters the selector" per the 7/19 contract. `ClaudeCodePreviewSettingsView` and the dead `AgentProvider.sidebarStatus` are deleted — the view was unreachable and claimed the app reads no Claude credentials or usage, which is false now.
3. **Data & Privacy documents Claude's data**: the usage cache and statusLine snapshot in `LocalDataInventory`, plus rows stating the Keychain credential is read but never stored and conversations are never read. The 7/19 contract keeps provider privacy facts in that one destination — do not add a Privacy card to the Agents page.
4. **The plan record was reconciled with the source.** Checkboxes here were stale in both directions; the "Status as of 2026-07-23" block near the top is now the accurate summary. Trust it over the individual boxes if they ever disagree again.

### Do this next, in this order

**1. The first-run "not set up" state (Task 3 Step 2b) — implemented 2026-07-23.**

`ClaudeSetupState.resolve` now distinguishes a genuine first run from a lapsed connection using current connection/usage evidence plus a durable monotonic setup-history flag. The centered setup card uses the shared provider tint and names credentials and passive status-line capture; later lapses retain the factual recovery page. The user accepted the first-run card in Light and Dark with the Context Rail hidden and visible on 2026-07-23.

**2. Bundle `ClaudeUsageBridge/` (wiring plan Task 6) — implemented 2026-07-23.** The app build copies the existing bridge into its Resources directory, and `ClaudeStatusLineInstaller` copies that signed, read-only resource into the deterministic app-owned Application Support path before use. The one-click statusLine configuration/merge UX remains separately deferred.

**3. Capability gate criterion #3 — closed 2026-07-23.** Anthropic's Pro/Max-specific help article now states directly that both individual plans share usage limits across Claude and Claude Code. That supports the existing weekly-scope copy without relying on Team/Enterprise behavior.

**Explicitly not your job:** the Usage Warnings section. Deferred by decision — Claude's chips ship with the general notification-settings port, which brings the per-provider threshold store with it. A stub now would be an inert card on a page that was just compacted. There is a comment in `ClaudeAgentSettingsView` saying so; leave it there.

### Conventions that will bite you if you skip them

- **Check `.agents/skills/` before starting** — `swiftui-pro` for view work, `writing-for-interfaces` for any copy, `test-driven-development` for logic. `AGENTS.md` opens with this because skipping it has already caused rework here.
- **One provider color, one source.** Never write a Claude color literal in a view. It goes in `settingsPresentationTint` or nowhere.
- **Width budget before any fixed trailing control.** `SettingsLayoutMetrics.trailingControlBudget(pageWidth:layout:)` derives it — 235pt at the default 499pt compact width. Long *text* values belong in `SettingsValueRow`, which wraps; `SettingsPreferenceControlRow` pins its trailing control's intrinsic width and will push the card past the trailing edge. That defect has shipped twice.
- **Codex must render byte-for-byte unchanged** after any shared-component edit.
- **Settings changes need signed-app acceptance** via `Scripts/build-app.sh` — source review is not visual verification, and an unobserved state gets recorded as unobserved rather than assumed.
