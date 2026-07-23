# Claude Settings Page Layout Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Per `AGENTS.md`, also use `.agents/skills/swiftui-pro` for the view work and `.agents/skills/writing-for-interfaces` for any copy change.

**Goal:** Fix four defects found in visual acceptance of the Claude agent Settings page: the section cards overflow the trailing page edge, explanatory copy wastes vertical space, the five-hour session note shows when it is irrelevant, and the "Force a reading" section is laid out poorly.

## Where this sits (state as of 2026-07-23)

Visual acceptance passed for the used/remaining setting and the connection-status derivation. These four are the remaining defects. All are on the Claude page only; the Codex page is unaffected and must stay byte-for-byte unchanged.

---

## Defect 1: section cards overflow the trailing page edge

**Symptom:** on the Claude page the section cards keep their leading gutter but run past the trailing edge, off-screen. Codex keeps an even gutter on both sides.

**This is a re-occurrence of a documented defect.** `AGENTS.md` → *Settings card geometry and mixed-axis layout guardrails* records the July 18 audit finding: *"General's fixed segmented control, leading-text minimum width, and card padding exceeded the 499-point Settings Page width, allowing that card to reach the trailing edge while other pages retained a gutter."* The guardrail that was written in response says to **calculate the complete width budget before adding a fixed trailing control**, and warns that *"a child `.frame(maxWidth: .infinity)` does not prevent intrinsic-width overflow."* The Claude page was built without doing that calculation.

**Root cause, quantified.** At the default hidden-rail width of 499pt — which is *below* the 500pt `compactWidthBreakpoint`, so compact metrics apply:

| Step | Value |
|---|---|
| Settings page width | 499 |
| − `compactPageHorizontalPadding` × 2 (16) | 467 |
| − `sectionContentHorizontalPadding` × 2 (14) | 439 |
| − `preferenceControlMinimumTextWidth` (168) | 271 |
| − `rowSpacing` × 3 (12; two HStack gaps + `Spacer(minLength:)`) | **235 available for the trailing control** |

`SettingsPreferenceControlRow` applies `.fixedSize(horizontal: true, vertical: false)` to its control, so the control refuses to compress and instead widens the row. Two Claude rows exceed the 235pt budget:

- **`Source → "Read from"`** — values like `"Cached Claude OAuth result · 3 hours ago"` (~40 characters, ≈260–280pt).
- **`Connection → "Status"`** — `"Signing in with Claude Code credentials…"` (~40 characters).

Codex's trailing values (`"Connected"`, `"Pro"`, `"143"`) all sit far under budget, which is why only Claude overflows.

- [x] **Step 1: Write a failing test** (`SettingsWidthBudgetTests.swift`) for a pure budget helper: `SettingsLayoutMetrics.trailingControlBudget(pageWidth:layout:)` returns 235 at 499pt compact, and a guard that the Claude source/status strings' estimated width exceeds it. Prefer asserting the *budget arithmetic*, not font metrics — measuring rendered text in a unit test is brittle.
- [x] **Step 2: Run to verify it fails.**
- [x] **Step 3: Implement.** Add the budget helper to `SettingsLayoutMetrics` so the number is derived, not folded into a comment. Then fix the two rows. **Preferred fix:** stop putting long, variable-length text in the fixed-size trailing control. Options, in order:
  1. Move the value into the leading column as the row's `description:` (already supported by `SettingsPreferenceControlRow`), leaving the trailing control for short values only.
  2. Introduce a `SettingsValueRow` variant whose trailing text is allowed to wrap (`.fixedSize(horizontal: false, vertical: true)`), for text-only values.
  3. Shorten the strings (last resort — it only defers the overflow).
- [x] **Step 4:** Verify Codex renders unchanged. **Run the full suite. Commit.**
- [x] **Step 5: Amend `AGENTS.md`** to note that the budget helper now exists and must be used, so the third occurrence of this defect is prevented rather than re-diagnosed.

## Defect 2: explanatory copy wastes vertical space; buttons are not right-aligned

**Symptom:** standalone description blocks consume full-width rows of vertical space, and action buttons sit left-aligned in their own full-width rows. Example called out: *"Live usage is temporarily unavailable; showing the last result."*

**Direction given:** buttons should be **right-aligned**; explanatory text should be **attached beneath the thing it explains**, in the existing subtext treatment (smaller, reduced opacity), rather than occupying its own block.

This matches the existing guardrail in `AGENTS.md`: *"Keep a control's explanatory description inside its leading control row whenever it explains that specific control… use standalone `SettingsDescription` only for section-level policy or recovery information."* Several Claude descriptions currently violate it.

- [x] **Step 1: Audit** every `SettingsDescription` and `Button` on the Claude page and classify each as (a) explains a specific control → move into that control's row as `description:`, or (b) genuine section-level policy → keep standalone. Record the classification in this plan before editing.
  - Candidates for (a): the staleness notice, the keychain disclosure, the keychain prompt explanation, the CLI footnote.
  - Likely (b): the weekly shared-pool caveat (section-level scoping fact).
- [x] **Step 2: Right-align buttons.** Establish one treatment for action rows — trailing-aligned button, matching how the trailing control column already works — and apply it to every Claude action. Do not hand-roll per-button alignment; add it to the shared row vocabulary so Codex can adopt it later without divergence.
- [x] **Step 3:** Re-check the width budget from Defect 1 after moving text into leading columns; longer leading text changes the wrap, not the overflow, but confirm.
- [x] **Step 4: Commit.**

## Defect 3: the five-hour session note shows when it is irrelevant

**Symptom:** `"Starts at your first message, then runs for five hours."` displays even when a five-hour window is already running, where it tells the user nothing and costs a line.

**Required behavior:** show the note **only when the current five-hour window has not started yet**. Once it is running, show only the reset information (`Resets in 2h 18m` + timestamp).

**Design question to settle first:** what does "not started" mean in the data? The candidate signal is `ClaudeUsageDisplayModel.fiveHour == nil` — no active window reported. But `nil` currently also covers *window has already reset* (`hasReset`) and *provider unavailable*. Those are three different states sharing one representation, and the note is only correct for the first.

- [x] **Step 1: Decide and record** how "no session started yet" is distinguished from "unavailable" and "already reset". If the OAuth payload cannot distinguish them, say so and pick the safest rule (likely: show the note only when the provider is connected **and** the five-hour window is absent).
- [x] **Step 2: Write failing tests**: note present when connected with no active five-hour window; note absent when a window is running; note absent when the provider is unavailable (no data at all, so the explanation would be noise).
- [x] **Step 3: Run to verify they fail.**
- [x] **Step 4: Implement** as a computed condition, not a view-body `if` — keep it testable alongside the rest of `ClaudeUsageDisplayModel`.
- [x] **Step 5: Run to verify they pass. Commit.**

## Defect 4: "Force a reading" section layout

**Symptom:** the section wastes vertical space — the button, its footnote, and the error slot each occupy separate full-width rows.

- [x] **Step 1: Restructure** to the Defect 2 pattern: right-aligned button with its footnote attached as subtext beneath it, rather than three stacked rows.
- [x] **Step 2:** Keep the consent prompt and the cost disclosure — the token cost must remain stated before the press. This is a layout change, **not** a reduction in what the user is told.
- [x] **Step 3:** Consider whether the section still needs its own `SettingsSection` header once compacted, or whether it belongs as a trailing action inside `Source`. Record the decision.
- [x] **Step 4: Commit.**

---

## Global constraints

- **Codex must render byte-for-byte unchanged.** Every shared-component edit is verified against the Codex page before commit (`AGENTS.md` reuse-over-fork rule).
- **No reduction in disclosed information.** The token cost, the keychain grant explanation, and the weekly shared-pool caveat all stay; this is about placement and density, not removal.
- **Never render a missing value as `0%`**, and keep cached/stale results visibly labelled (capability gate #5, probe plan §7/§9).
- **All geometry values live in `SettingsLayoutMetrics`** — no literals in views.
- **Required visual acceptance:** per `AGENTS.md`, Settings changes need signed-app acceptance. Inspect the Claude page beside Codex at the default size, rail hidden and visible, both appearances, checking equal gutters on both edges.

## Verification matrix

| Check | State | Result |
|---|---|---|
| `swift test` | Run | 208 passed, 0 failures (204 at the time of the fixes; +4 from the provider-promotion tests) |
| Claude page gutters equal at 499pt, rail hidden | Run | **Accepted** — user visual acceptance, 2026-07-23 |
| Claude page gutters equal, rail visible | Run | **Accepted** — user visual acceptance, 2026-07-23 |
| Codex page unchanged side by side | Run | No diff in CodexAgentSettingsView, AgentQuotaSessionSection, SettingsPreferenceControlRow |
| Five-hour note appears only pre-session | Partial | Logic covered by `ClaudeUsageDisplayModelTests`; the pre-session state was not separately driven in the app — the observed account had a window running |
| Long source string (`Cached … · 3 hours ago`) does not overflow | Run (unit) | Value now wraps via SettingsValueRow; budget asserted at 235pt |
| Both appearances (light/dark) | Observed | **Accepted** — user visual acceptance, 2026-07-23 |
| Claude `#D97757` tint across five-hour and weekly quota bars | Observed | **Accepted** — user visual acceptance, 2026-07-23 |

**Acceptance recorded 2026-07-23.** The user inspected the running app and accepted the page in both appearances and rail states. The user subsequently inspected the `#D97757` treatment across the five-hour and weekly quota bars and accepted that update. One qualification remains: the pre-session five-hour state was not separately driven because the observed account had a window running.

## Completion criteria

- Claude section cards have equal leading and trailing gutters at the default width, with the longest realistic source string.
- Action buttons are right-aligned; control-specific explanations sit with their control as subtext.
- The five-hour session note appears only before a session has started.
- "Force a reading" is compact, still states its token cost, and still confirms on first use.
- Codex renders unchanged; full suite green; signed-app visual acceptance recorded above.

## Outcome

**All four defects closed and accepted 2026-07-23.** This plan is done. Its two lasting artifacts are `SettingsValueRow` (the wrapping text-value row) and `SettingsLayoutMetrics.trailingControlBudget`, which `AGENTS.md` now points at so the overflow defect is prevented rather than diagnosed a third time. Remaining Claude Settings work lives in the [settings page port plan](2026-07-21-claude-agent-settings-page-port.md), not here.
