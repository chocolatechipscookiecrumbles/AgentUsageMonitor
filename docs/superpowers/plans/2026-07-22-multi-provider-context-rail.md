# Multi-Provider Context Rail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Settings context rail from a single card describing the *selected* agent into **one status block per active provider**, and replace the low-value rows with the numbers a user actually opens the rail for: the five-hour and weekly limits, whether the provider is connected, and when it last refreshed.

## Where this sits (state as of 2026-07-22)

[AgentConnectionsContextView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift) renders **one** `SettingsContextCard("Agent Status")` for whichever provider is selected, via `switch provider`. Today's Codex card shows:

| Row | Value | Verdict |
|---|---|---|
| header | connection state + icon | keep |
| `Current` | `"OpenAI Codex"` | **remove** — it restates the page you are already on |
| `Plan` | `"Pro"` | keep unchanged |
| `Quota status` | `status.displayMode.displayName` | **repurpose** — should say connected or not |
| — | — | **add** five-hour limit |
| — | — | **add** weekly limit |
| — | — | **add** last refresh |

The Claude branch still renders a **"Preview" / "Not available yet"** card asserting the app "does not read its files, credentials, usage, or account data." That is now false — Claude is live via the Claude Code Keychain credential — so it is a correctness fix, not just a redesign.

`SettingsContextPanel` already wraps its content in a `ScrollView` at a fixed `contextRailWidth`, so stacking several cards needs no layout change.

## Target

One card per **active** provider, stacked in the rail:

```
┌─ Codex ──────────────────┐   ┌─ Claude ─────────────────┐
│ [icon] Connected         │   │ [icon] Connected         │
│ ─────────────────────────│   │ ─────────────────────────│
│ Plan            Pro      │   │ Plan            Pro      │
│ Five-hour       44%      │   │ Five-hour       14%      │
│ Weekly          28%      │   │ Weekly          25%      │
│ Status          Connected│   │ Status          Connected│
│ Last refresh    2 min ago│   │ Last refresh    8 min ago│
└──────────────────────────┘   └──────────────────────────┘
```

## Design decisions to settle first

**1. Which providers get a block?** Only providers with a real read — Codex and Claude. **Never GitHub Copilot** until its capability gate passes, matching the rule applied to the menu tabs and settings pages. The list is a computed `activeProviders`, not `AgentProvider.allCases`.

**2. Does the rail still track the selected agent?** Two readings of "a block per active provider":
   - **(a) All active providers always**, regardless of which agent page is open — the rail becomes an at-a-glance dashboard.
   - **(b) Selected provider first, others below** — keeps context tied to the page while still showing the rest.
   - **Recommendation: (a).** The rail's value is comparing providers without switching pages; (b) reintroduces the "Current" row's redundancy in ordering form. Settle in Task 1.

**3. What does "Last refresh" mean per provider?** They are not the same clock and must not be conflated:
   - **Codex** has `displayState.lastAttemptAt` (when we tried) and `lastConfirmedAt` (when we last got a confirmed result). Showing *attempt* would call a failing provider "refreshed 1 min ago."
   - **Claude** has `snapshot.capturedAt`, already rendered relatively by `ClaudeUsageDisplayModel.capturedAtText` ("8 minutes ago").
   - **Recommendation: last *successful* data timestamp for both** — Codex `lastConfirmedAt`, Claude `capturedAt` — so the row always answers "how old is this number." Record in Task 1.

**4. What do the limit rows show when disconnected?** **Not `0%`.** An absent window renders "—" or "Unavailable", per capability gate criterion #5 and the existing rule in `ClaudeUsageDisplayModel`. This is the single easiest place to accidentally invent a quota.

## Architecture

- **`ProviderContextSummary`** — one provider-neutral value type carrying everything a block renders: `provider`, `isConnected`, `statusText`, `planText?`, `fiveHourText?`, `weeklyText?`, `lastRefreshText?`. Built by pure adapters, so the rail view has no per-provider branching and no formatting logic.
- **`CodexContextSummaryAdapter`** — from `AgentConnectionState` + `QuotaPresentation` + `QuotaDisplayState`.
- **`ClaudeContextSummaryAdapter`** — from `ClaudeConnectionState` + `ClaudeUsageDisplayModel`. Reuses the display model's existing percent and relative-time formatting rather than re-deriving it.
- **`ProviderContextCard`** — renders one `ProviderContextSummary` using the existing `SettingsContextCard` / `SettingsContextValueRow` / `SettingsPaletteDivider` primitives and `AgentSettingsIcon`. No new visual vocabulary.
- **`AgentConnectionsContextView`** — becomes a `ForEach` over `activeProviders` emitting `ProviderContextCard`, replacing the `switch`. The Claude "Preview" card is deleted outright.

**Tech Stack:** SwiftUI, XCTest. No new dependencies. All formatting logic lives in the adapters so it is unit-testable; the card itself stays declarative.

## Global constraints

- **No provider block without a real read** — Copilot stays absent.
- **Never render a missing limit as `0%`** (gate #5).
- **Never present a stale number as current** — if the underlying data is cached/expired, the last-refresh row must make its age visible; Claude's `stalenessNotice` already distinguishes this.
- **Delete the false Claude preview copy** — it claims the app reads nothing, which is no longer true.
- **Presentation logic in testable structs**, not view bodies, matching `SettingsStatus` / `ClaudeUsageDisplayModel` / `ClaudeSignInPresentation`.
- **TDD for the adapters**; full suite green each task.

---

## Task 1: Settle the three open decisions — DECIDED 2026-07-22

- [x] **Step 1: Recorded.**
  1. **All active providers, always** — the rail does not track the selected agent. It is an at-a-glance dashboard across providers.
  2. **Last successful data timestamp, for all providers** — Codex uses `lastConfirmedAt` (not `lastAttemptAt`), Claude uses `capturedAt`. A provider whose refresh is failing must not read as recently refreshed. Rendered relatively ("8 minutes ago") through one shared formatter so providers cannot drift.
  3. **Placeholder is "Unavailable"** for absent values, and the status row reads **"Disconnected"** when not connected. Never `0%`.
  4. **Each block's header shows the provider name** ("Codex", "Claude") beside the icon, not the icon alone.
- [x] **Step 2: Commit** the decision record before writing code.

## Task 2: `ProviderContextSummary` + the two adapters

- [x] **Step 1: Failing tests** (`ProviderContextSummaryTests.swift`):
  - Codex connected with quota → plan, both limits as `NN%`, `isConnected == true`, last refresh from the **confirmed** timestamp.
  - Codex disconnected → limits are the placeholder, **never `0%`**; `isConnected == false`.
  - Claude available → limits and last-refresh text come from `ClaudeUsageDisplayModel` (assert it is reused, not re-derived).
  - Claude unavailable → placeholders, not zeros.
  - A window past its reset is not reported as a current figure.
  - Missing plan renders the placeholder rather than an empty string.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** the summary type and both adapters.
- [x] **Step 4: Run to verify they pass. Commit.**

## Task 3: `ProviderContextCard`

- [x] **Step 1: Implement** the card from a `ProviderContextSummary` using the existing context primitives: header (`AgentSettingsIcon` + status text tinted `provider.settingsPresentationTint`), divider, then Plan / Five-hour / Weekly / Status / Last refresh rows.
- [x] **Step 2:** Verify row order and labels match the target above; no `Current` row.
- [x] **Step 3: Commit.**

## Task 4: Stack one card per active provider

- [x] **Step 1: Failing tests** for `activeProviders`: Codex always included; Claude included only when it has a usable state; **Copilot never**; ordering is deterministic.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement.** Replace `AgentConnectionsContextView`'s `switch` with a `ForEach` over `activeProviders`. **Delete the Claude preview card and its false privacy copy.** Thread Claude's state in from `QuotaViewModel` (it already publishes `claudeState` and `claudeConnectionState`).
- [x] **Step 4:** Confirm the rail scrolls correctly with two cards at `contextRailWidth`. **Run the full suite. Commit.**

## Task 5: Verify and document

- [ ] **Step 1:** Manual check against the live account: both cards show real numbers, a disconnected provider shows placeholders rather than zeros, and last-refresh ages advance.
- [ ] **Step 2:** Extend [the verification guide](../../claude-usage-verification.md) with a rail section.
- [ ] **Step 3: Commit.**

---

## Explicitly deferred (not dropped)

- **GitHub Copilot block** — blocked on its capability gate.
- **Per-provider refresh action in the rail** — the rail stays read-only here; refresh lives on the agent page and in the menu.
- **Live-ticking relative times** — "8 minutes ago" is computed at render, not on a timer. A ticking clock is a separate concern.

## Completion criteria

- The rail shows one block per active provider (Codex + Claude), never Copilot.
- Each block shows Plan, five-hour, weekly, connected status, and last refresh — and **no** "Current" row.
- A disconnected or unavailable provider shows placeholders, never `0%`.
- The false Claude "Preview / does not read your data" copy is gone.
- Full suite green.
