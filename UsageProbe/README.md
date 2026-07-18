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

The native companion has a separate macOS Settings window with General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics destinations in its global `SettingsNavigationSidebar`. It begins with the Context Rail hidden at 680 × 560 points. The page-header control shows the 210-point rail by adding 211 points at the right edge, without widening the sidebar or page; visibility is local to the open window. General contains working Launch at Login, System/Light/Dark app appearance, keyboard-shortcut enablement, and menu-bar presentation controls. Its sole full-width menu-bar preview is in the Context Rail; Current Label, Current Scope, and the page-level duplicate Preview are absent. Current independent Boolean preferences in General and Notifications use accessibility-labelled native switches. The Menu Bar section switches between the gauge and a dual `5H: x% | Week: x%` label, while **Show** switches both appearances between Remaining and Used values. Remaining is the default. The label and preview update immediately after each accepted quota refresh and follow the existing Refresh schedule rather than running another timer. Notifications contains the working permission and category controls. Refresh provides Automatic, 1 minute, 1 minute 30 seconds, 2 minutes (default), 5 minutes, and 10 minutes plus the real manual-refresh action, current effective policy, and refresh timestamps. Automatic may temporarily use 30 seconds near an imminent threshold, qualified exhaustion, or reset verification. After three consecutive unsuccessful reads, every mode temporarily retries every 10 minutes until a confirmed update restores the selected schedule. Agents is one grouped, scrollable Settings page for OpenAI Codex, Claude Code, and GitHub Copilot. Codex is the only active integration; the other agents are planned and not connected. The Codex section and the menu share checking, missing-CLI, disconnected, signing-in, connected, and recoverable-failure states. Other destinations report current app, collection, retention, and classified-outcome status without exposing fingerprints or raw errors. Export and deletion remain later work. The fixed 50%, 25%, 10%, and 5% remaining-quota thresholds are independently selectable and apply to both the five-hour and weekly lanes; forecast and reset-credit-expiration warnings can also be disabled independently. Earlier signed-app evidence established the System/Light/Dark presentation model and native-menu boundary; the direct real-window appearance matrix after this Context Rail/control change remains required manual acceptance and is not claimed here. These preferences affect only the native app and do not change the Python probe.

All Settings destinations use the same native, scrollable page layout with consistent margins, section spacing, aligned labels, bounded control widths, and wrapping helper text. This prevents long labels or descriptions from clipping at the window edge while retaining the bare system SwiftUI appearance.

The menu-bar companion uses native inline menu commands for refresh, Settings, notification permission recovery, and quit. Its stable refresh-timing row shows the last attempt beside the absolute next-refresh time, then replaces that text with **Refreshing…** and the newly scheduled absolute time at semantic refresh transitions. It does not invalidate the tracked native menu once per second. Confirmed/completed identifies a trusted latest live result; cached/paused preserves and labels the last confirmed result after an unsuccessful latest attempt, with separate success and attempt times. A disabled-notification status is shown as its own concise row so it does not overlap refresh metadata or actions.

The configurable menu-bar label consumes that same confirmed/completed or cached/paused state. The dual appearance uses `5H: 64% | Week: 82%`; Used mode displays each value's complement, an unavailable lane displays `—`, and cached/paused values carry a pause marker. Changing either General preference updates the label immediately. Quota values update after launch, wake, authentication, manual, and scheduled refreshes using the interval selected in Refresh.

When Codex is not connected, the menu replaces quota controls with a dedicated connection stage. **Sign in with browser** uses the Codex app-server's provider-generated URL and completion event. **Sign in with Codex CLI…** opens Terminal visibly, runs the located `codex login`, polls `codex login status`, and confirms the account with `account/read`. Neither path reads or stores credentials, and successful confirmation triggers one quota refresh. **Settings…** and **Quit Codex Usage Monitor** remain the final commands in both connected and disconnected stages.

When independent `codex login` completes while the monitor is disconnected, the connection controller silently reads the same Codex home on application activation and at most every 30 seconds while disconnected. It uses read-only `account/read`, does not inspect credential files, and does not add a second quota schedule. Isolated user acceptance observed both triggers; exact authentication-refresh count, repeated-event coalescing, negative, logout, sleep/wake, and teardown checks remain unobserved.

Connection verification on 2026-07-13 covered Swift compilation, a confirmed live one-shot quota read, signed-bundle startup, absence of a new crash report, and process survival with an isolated empty `CODEX_HOME`. User-reported manual acceptance also confirmed the disconnected menu and successful browser/CLI sign-in transitions. Verification does not log out or modify the user's active Codex account automatically.

Native notification controls also cover confirmed resets, reset failures verified by two post-reset reads, data older than 15 minutes, and extended update interruptions. The interruption notice appears once on the third consecutive unsuccessful refresh, cautiously says the user may be disconnected, and is not repeated during the same persisted episode; overlapping stale-data notices are suppressed until recovery. Missing Codex CLI and signed-out states use the dedicated connection UI instead. The app does not implement its own quiet-hours schedule; use macOS Focus or notification settings for time-based silencing. No notification stores raw provider errors or changes the probe's read-only safety boundary.

Turning off **Enable quota notifications** greys every subordinate warning control without erasing its stored value. Notification authorization status and **Open Notification Settings…** remain available so denied macOS permission can still be repaired.

The native app reports macOS notification authorization separately from its alert preference. When system permission is denied, it links to Notification Settings because macOS does not repeat the original permission prompt. Both the popover and separate Settings window observe the same state.

A separate future `feature/figma-ui-overhaul` branch is reserved for adapting approved Figma designs to the native Settings and Dashboard windows after their behavior stabilizes. That frontend-only work must preserve native menu commands and must not alter the Python probe, quota collection, scheduling, authentication, notification policy, or storage schemas.
