# Codex capability probe

This Phase 0 harness checks whether the locally installed Codex exposes useful account limits and token-usage summaries without starting a model turn.

## Safety boundary

The process runner allows only:

- `codex --version`
- `codex login status`
- `codex doctor --json` (reserved for diagnostics)
- `codex app-server --listen stdio://`

The app-server session follows `initialize` → `initialized` → `account/read` → `account/rateLimits/read` → `account/usage/read`. It cannot execute prompts, log out, or consume reset credits. The probe never reads `auth.json`; it records metadata only for an explicit allowlist of non-secret local state files.

The app-server methods are experimental in the installed Codex schema, so successful results are classified as `experimental`, not `supported`.

## Run

From this directory:

```sh
python3 -m codex_probe
```

The default output is a compact summary of plan type, credits, earned reset credits and their expiry dates, five-hour usage, weekly usage, and reset times. The probe performs three read-only samples, rejects the observed transient near-empty response pattern, and labels a result unconfirmed when clean samples disagree.

For a confirmed result, the probe requires the same hashed account identity, the `codex` rate-limit lane, matching reset windows, and near-identical usage across clean samples. It saves only the last confirmed non-secret quota snapshot to `~/.codex-usage-probe/last-known-good.json`, with owner-only directory and file permissions. The stored snapshot contains a one-way account fingerprint, not the email address, credentials, prompts, or raw provider response.

Optional overrides:

```sh
python3 -m codex_probe --codex /path/to/codex --codex-home /path/to/.codex
python3 -m codex_probe --json
```

`--json` prints the complete normalized report. Raw app-server responses and credential contents are never included.

## Native app companion

The native Swift menu-bar MVP now lives in `../CodexUsageMonitor`. It independently implements this same read-only app-server protocol and validation policy; it does not embed or invoke this Python harness.

Build and launch it with:

```sh
cd ../CodexUsageMonitor
bash Scripts/build-app.sh
open .build/CodexUsageMonitor.app
```

This prototype is verified through compilation and live, read-only Codex responses at the user's direction. No generated test cases were added or run for this work.

The native app additionally retains a bounded sanitized history at `~/Library/Application Support/CodexUsageMonitor/quota-history.json`: maximum 500 confirmed observations and 90 days. It stores only provider/lane identifiers, a one-way account fingerprint, normalized quota windows, and collection times. A forecast requires at least three confirmed observations spanning 15 minutes in one reset window and a consistently positive median-adjacent slope; valid forecasts include low, medium, or high confidence.

Menu-bar refresh outcomes are stored separately at `~/Library/Application Support/CodexUsageMonitor/refresh-diagnostics.json`, with a 30-day/1,000-entry limit and owner-only permissions. Diagnostics contain only timestamps, launch/scheduled/wake/manual reason, classified outcome, and an optional stable failure kind. They never contain raw provider errors or account quota values. The Python probe does not read or write either native-app store.

The native companion has a separate macOS Settings window with General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics tabs. Notifications contains the working permission and category controls. Refresh provides Automatic, 1 minute, 1 minute 30 seconds, 2 minutes (default), 5 minutes, and 10 minutes plus the real manual-refresh action, current effective policy, and refresh timestamps. Automatic may temporarily use 30 seconds near an imminent threshold, qualified exhaustion, or reset verification; repeated unsuccessful reads back off to five minutes. Agents uses a left provider sidebar with a separate in-tab detail pane for OpenAI Codex, Claude Code, and GitHub Copilot. Codex is the only active integration; the other agents are planned and not connected. The Codex pane and the menu share checking, missing-CLI, disconnected, signing-in, connected, and recoverable-failure states. Other tabs report current app, collection, retention, and classified-outcome status without exposing fingerprints or raw errors. Launch at Login, System/Light/Dark appearance, export, and deletion remain later work. Remaining-quota thresholds stay fixed at 50%, 25%, 10%, and 5% for both the five-hour and weekly lanes; forecast and reset-credit-expiration warnings can be disabled independently. These preferences affect only the native app and do not change the Python probe.

The menu-bar companion uses native inline menu commands for refresh, Settings, notification permission recovery, and quit. It shows the last attempt beside a live next-refresh countdown that continues ticking while the menu remains open. Confirmed/completed identifies a trusted latest live result; cached/paused preserves and labels the last confirmed result after an unsuccessful latest attempt, with separate success and attempt times. A disabled-notification status is shown as its own concise row so it does not overlap refresh metadata or actions.

When Codex is not connected, the menu replaces quota controls with a dedicated connection stage. **Sign in with browser** uses the Codex app-server's provider-generated URL and completion event. **Sign in with Codex CLI…** opens Terminal visibly, runs the located `codex login`, polls `codex login status`, and confirms the account with `account/read`. Neither path reads or stores credentials, and successful confirmation triggers one quota refresh. **Settings…** and **Quit Codex Usage Monitor** remain the final commands in both connected and disconnected stages.

Connection verification on 2026-07-13 covered Swift compilation, a confirmed live one-shot quota read, signed-bundle startup, absence of a new crash report, and process survival with an isolated empty `CODEX_HOME`. Visual inspection and completing both sign-in paths while deliberately signed out remain manual checks; verification does not log out or modify the user's active Codex account.

Native notification controls also cover confirmed resets, reset failures verified by two post-reset reads, data older than 15 minutes, and three or more consecutive refresh failures. Optional local-time quiet hours defer noncritical delivery; users may allow critical 5%-remaining and reset-failure warnings through. No notification stores raw provider errors or changes the probe's read-only safety boundary.

The native app reports macOS notification authorization separately from its alert preference. When system permission is denied, it links to Notification Settings because macOS does not repeat the original permission prompt. Both the popover and separate Settings window observe the same state.

A separate future `feature/figma-ui-overhaul` branch is reserved for adapting approved Figma designs to the native Settings and Dashboard windows after their behavior stabilizes. That frontend-only work must preserve native menu commands and must not alter the Python probe, quota collection, scheduling, authentication, notification policy, or storage schemas.
