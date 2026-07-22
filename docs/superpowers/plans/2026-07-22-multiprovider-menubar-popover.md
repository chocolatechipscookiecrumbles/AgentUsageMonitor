# Multi-Provider Menu Bar Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the menu bar surface from a single-provider Codex menu into a **multi-provider popover with a provider tab strip**, so Claude (and later Copilot) are first-class alongside Codex. Today [QuotaMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift) renders Codex content directly with no notion of a provider, and the menu bar label shows only Codex's number.

## Where this sits (state as of 2026-07-22)

- **The menu is a `MenuBarExtra` in its default `.menu` style** ([CodexUsageMonitorApp.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift)). That style renders a system menu of rows — it **cannot host a tab strip**. Moving to `.menuBarExtraStyle(.window)` is a prerequisite, and it is a real visual change: the popover becomes an arbitrary SwiftUI panel rather than a native menu.
- **`AgentProvider` already exists** with `tabTitle` ("Codex"/"Claude"/"Copilot"), `systemImage`, and `settingsPresentationTint` — the tab strip can be driven off it directly rather than inventing a parallel enum.
- **Settings already solved this exact problem**: `AgentSettingsTabStrip` + `AgentsSettingsView` switch on `AgentProvider`. The menu should mirror that structure so the two surfaces stay consistent.
- **`QuotaViewModel` is Codex-centric.** It owns `QuotaMonitor` and `CodexConnectionController` and exposes `presentation`, `displayState`, `fiveHourForecast` etc. as bare properties. Claude's monitor is being added by the [wiring plan](2026-07-21-claude-usage-provider-wiring.md); this plan consumes it rather than duplicating it.
- **Claude tier 1 is live via the Claude Code Keychain credential**; browser sign-in is [shelved](2026-07-21-claude-oauth-web-login-spike-findings.md#addendum--claude-setup-token-shelved-as-unresolved-2026-07-22). Copilot's capability gate has **not** passed, so it must not appear.

## Design decisions to settle first

**1. Which providers get a tab?** Only providers with a real read. Codex (live) and Claude (live after wiring). **Copilot stays absent** until its gate passes — an empty tab advertising an unsupported provider is the "static preview" mistake the Claude gate already rejected. The tab strip is therefore built from a computed `availableProviders`, not `AgentProvider.allCases`.

**2. What does the menu bar *label* show with N providers?** This is the genuinely new question — there is one label and now several numbers. Options:
   - **(a) A single chosen provider** (user picks a "primary" in Settings). Predictable, no new UI logic, but ignores the other provider's state.
   - **(b) Worst-case across providers** — show whichever is nearest its limit. Most useful for the app's actual purpose (don't get surprised by a limit), but the label silently changes which provider it refers to, so it **must carry the provider's icon/initial** to stay honest.
   - **(c) Both, compact** (`C 26% · ⌥ 14%`). Most information, but menu bar width is scarce and it degrades badly at 3+ providers.
   - **Recommendation: (b) with a mandatory provider glyph**, falling back to (a) if the user pins a primary. Decide in Task 1; it drives `MenuBarLabelPresentation`.

**3. Does the popover remember the selected tab?** Yes — persist in `AppSettings`, defaulting to the pinned/primary provider, so opening the menu doesn't reset context every time.

**4. What stays global?** "Settings…" and "Quit" remain a single footer below the tab content, not per-provider.

## Architecture

- **`MenuProviderTab`** — a small presentation type built from `AgentProvider` (title, glyph, tint, plus a `badge` for an at-risk provider), so the strip has no view-embedded logic.
- **`MenuBarPopoverView`** (new root) — replaces `QuotaMenuView` as the `MenuBarExtra` content: a provider tab strip, the selected provider's body, then the shared footer. Renders in `.window` style.
- **`CodexMenuSection`** — the existing `ConnectedQuotaMenuView` / `CodexDisconnectedMenuView` pair, moved behind a provider-agnostic container. No behavior change; this is a lift, not a rewrite.
- **`ClaudeMenuSection`** (new) — Claude's 5h/7d windows, source label + relative capture time, and the explicit unavailable state. Driven by `ClaudeUsageDisplayModel` from the wiring plan (reuse, do not duplicate the mapper).
- **`MenuBarLabelPresentation`** — extended to take a set of provider summaries and resolve the label per decision (2), always pairing a number with the provider it belongs to.
- **`QuotaViewModel`** — gains `selectedMenuProvider` and a provider-summary collection. **Not** split into per-provider view models in this plan: that is a larger refactor and the wiring plan is already changing this type. Note the tension explicitly rather than doing both at once.

**Tech Stack:** SwiftUI (`MenuBarExtra` `.window` style), Combine, XCTest. No new dependencies.

## Global constraints

- **No provider appears without a real read.** No placeholder tabs, no "coming soon" (the Claude capability gate's rule, generalized).
- **The label must never show a number without indicating which provider it is** — an unlabelled percentage that silently switches providers is actively misleading.
- **Presentation logic goes in testable structs**, not view bodies, matching `MenuBarLabelPresentation` / `SettingsStatus` / `ClaudeSignInPresentation`.
- **`.window` style is a visual regression risk**: the popover loses native menu behaviors (keyboard traversal, auto-dismiss on action, standard metrics). Each task must check the popover still dismisses correctly after an action.
- **TDD throughout**; full suite green each task.

---

## Task 1: Settle the label rule and model provider summaries

- [ ] **Step 1: Failing tests** (`MenuProviderSummaryTests.swift`): a summary carries provider + percent + availability; the "most at risk" selection picks the highest utilization; providers with no data are excluded rather than treated as 0%; a tie resolves deterministically (stable provider order).
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** `MenuProviderSummary` and the selection rule. **Record the decision from §2 in this plan** before implementing.
- [ ] **Step 4: Run to verify they pass. Commit.**

## Task 2: Extend `MenuBarLabelPresentation` for multiple providers

- [ ] **Step 1: Failing tests**: with one provider the label is unchanged from today (no regression for Codex-only users); with two, the label shows the at-risk provider **and its glyph**; with none available, the existing unavailable label is preserved.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Keep the existing single-provider entry point delegating to the new one so `MenuBarStatusLabel` changes minimally.
- [ ] **Step 4: Run the full suite. Commit.**

## Task 3: Switch `MenuBarExtra` to `.window` and add the tab strip

- [ ] **Step 1: Implement `MenuProviderTab` + `MenuBarProviderTabStrip`**, driven by `availableProviders` (Codex always; Claude when its monitor reports a usable state; never Copilot). Mirror `AgentSettingsTabStrip`'s look.
- [ ] **Step 2: Implement `MenuBarPopoverView`** hosting strip + selected body + shared footer, and switch the app to `.menuBarExtraStyle(.window)`.
- [ ] **Step 3: Failing tests** for `availableProviders` (pure function over connection/usage state): Copilot never included; Claude included only with a usable state; Codex always.
- [ ] **Step 4: Manually verify** the popover opens, tabs switch, and it **dismisses correctly** after "Settings…" and after a refresh action — the main `.window`-style regression risk. **Commit.**

## Task 4: Move Codex content behind the tab (no behavior change)

- [ ] **Step 1:** Extract today's `QuotaMenuView` body into `CodexMenuSection`, keeping `ConnectedQuotaMenuView` / `CodexDisconnectedMenuView` as-is.
- [ ] **Step 2:** Verify by inspection and manual run that every existing affordance still works: sign-in buttons, alerts toggle, refresh-now, notification-settings link, forecasts.
- [ ] **Step 3: Run the full suite. Commit.**

## Task 5: Add the Claude tab

- [ ] **Step 1: Implement `ClaudeMenuSection`** from `ClaudeUsageDisplayModel`: five-hour and weekly rows, source label + relative capture time, the shared-pool caveat on the weekly row, and an explicit unavailable state with a manual-refresh affordance. **Never** render zeros for missing data.
- [ ] **Step 2:** Cached/stale/expired deliveries must be visibly labelled (probe plan §7/§9).
- [ ] **Step 3:** Manual verification against the live account; **commit.**

## Task 6: Persist the selected tab

- [ ] **Step 1: Failing tests**: the selected provider round-trips through `AppSettings`; an unavailable persisted provider (e.g. Claude signed out) falls back to the default rather than showing an empty tab.
- [ ] **Step 2: Implement. Run the full suite. Commit.**

## Task 7: Documentation

- [ ] **Step 1:** Update the planning board with the menu surface's new state and note the deferred per-provider view-model split.
- [ ] **Step 2:** Extend [the verification guide](../../claude-usage-verification.md) with menu-level manual checks. **Commit.**

---

## Explicitly deferred (not dropped)

- **Per-provider view models.** `QuotaViewModel` stays a single type here. Splitting it is a larger refactor that collides with the wiring plan's changes to the same file; do it once both have landed.
- **GitHub Copilot tab** — blocked on its capability gate, not on this plan.
- **Reordering / hiding tabs by user preference**, and a pinned-primary provider if decision (2) lands on the at-risk rule.

## Completion criteria

- The menu bar popover shows a provider tab strip with Codex and Claude, and no provider lacking a real read.
- Every existing Codex menu affordance still works, and the popover dismisses correctly after actions under `.window` style.
- The menu bar label never shows a bare percentage without identifying its provider.
- Claude's menu section labels stale/cached data and shows an explicit unavailable state rather than zeros.
- Selected tab persists across opens; full suite green.
