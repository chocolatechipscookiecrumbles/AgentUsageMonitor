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

The native companion has a separate macOS Settings window with General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics destinations in its global `SettingsNavigationSidebar`. It begins with the Context Rail hidden at 680 × 560 points. The page-header control shows the 210-point rail by adding 211 points at the right edge, without widening the sidebar or page; visibility is local to the open window. General contains working Launch at Login, keyboard-shortcut enablement, and a **Menu Bar Icon** group with **Style**, **Show**, and Settings-window **Appearance** segments for System, Light, and Dark. Appearance changes the Settings presentation only; the native menu remains controlled by macOS. Its sole full-width menu-bar preview is in the Context Rail; Current Label, Current Scope, and the page-level duplicate Preview are absent. Diagnostics owns the app Name, Version, and Build rows. Current independent Boolean preferences in General and Notifications use accessibility-labelled native switches. The Menu Bar section switches between the gauge and a dual `5H: x% | Week: x%` label, while **Show** switches both appearances between Remaining and Used values. Remaining is the default. The label and preview update immediately after each accepted quota refresh and follow the existing Refresh schedule rather than running another timer. Notifications contains the working permission and category controls. Refresh provides Automatic, 1 minute 30 seconds, 2 minutes (default), 5 minutes, and 10 minutes plus the real manual-refresh action, current effective policy, and refresh timestamps. Automatic may temporarily use 30 seconds near an imminent threshold, qualified exhaustion, or reset verification. After three consecutive unsuccessful reads, every mode temporarily retries every 10 minutes until a confirmed update restores the selected schedule. Agents is one grouped, scrollable Settings page for the supported OpenAI Codex and Claude Code providers; unsupported providers are omitted. Claude shows its connection, current quota, source, and an explicitly consented CLI reading. On a genuine first run it instead shows a setup card that offers Claude Code credentials and explains passive status-line capture, including the Keychain disclosure before the connect action. Once this app has connected or held a reading, a later lapse keeps the factual recovery page rather than showing onboarding again. The signed app now bundles the passive-capture bridge and copies it to app-owned Application Support before use; the one-click statusLine configuration/merge UI remains deferred. Other destinations report current app, collection, retention, and classified-outcome status without exposing fingerprints or raw errors. Export and deletion remain later work. The fixed 50%, 25%, 10%, and 5% remaining-quota thresholds are independently selectable for Codex's five-hour and weekly lanes; Claude warnings remain deferred to the general notification-settings port. The factual Claude page, first-run card in both appearances and rail states, and the Claude tint across the five-hour and weekly quota bars passed user visual acceptance on 2026-07-23. Proper Developer ID signing is deferred until per-agent notifications and the menu-bar popover are complete. These preferences affect only the native app and do not change the Python probe.

Refresh behavior correction — 2026-07-18: the picker no longer offers one minute; its shortest fixed choice is **1 minute 30 seconds**, and a persisted legacy `one-minute` selection normalizes to that value. **Refresh on wake** is a persisted switch that defaults enabled. Opening the native menu never starts a refresh, timer, polling loop, retry loop, or second scheduler; use **Refresh now** for an explicit manual collection.

All Settings destinations use the same native, scrollable page layout with consistent margins, section spacing, aligned labels, bounded control widths, and wrapping helper text. This prevents long labels or descriptions from clipping at the window edge while retaining the bare system SwiftUI appearance.

The menu-bar companion presents a multi-provider popover with **Codex** and **Claude** tabs and a bottom action row for **Refresh Now**, **Notification Settings**, **Preferences…**, and **Quit**; it reopens on the last-viewed tab. **Refresh Now** targets the active provider, keeps the popover open, and shows progress in place; the other commands dismiss first. Each tab's header shows the provider name, a standard `Updated: <time> · <how long ago>` freshness line, and a **Confirmed / Cached / Refreshing / Unavailable** status pill; the separate next-refresh-timing row was removed with the Figma port. Claude's data source rides in a `Read from: <source>` caption in the tab content rather than the header. The popover intentionally uses bounded intrinsic content and does not scroll: Codex shows at most two reset-credit expiry dates there, with any additional dates and the complete list available in Settings. Opening the popover does not refresh, poll, or invalidate anything once per second. Confirmed/completed identifies a trusted latest live result; cached/paused preserves and labels the last confirmed result after an unsuccessful latest attempt, surfaced as a cached warning strip above the window cards. Expired Claude windows are excluded from the compact menu-bar summary. The per-quota-alert toggle is not in the popover (it lives in Settings); when macOS notification permission is denied, a slim recovery strip with **Open System Notification Settings** appears on both tabs.

The configurable menu-bar label consumes that same confirmed/completed or cached/paused state. With only Codex data available, its behavior is unchanged: the dual appearance uses `5H: 64% | Week: 82%`, Used mode displays each value's complement, an unavailable lane displays `—`, and cached/paused values carry a pause marker. When Claude is the only usable read or both providers have data, the compact label selects the provider with the highest utilization across its available windows and shows that provider's mark beside the value. A cached Codex selection or cached/passive Claude selection carries the same compact non-confirmed marker, and accessibility names the selected reading as confirmed, cached, or passive. Missing provider values are excluded rather than treated as zero, and equal utilization resolves in stable Codex-then-Claude order. Changing either General preference updates the label immediately. Quota values update after launch, enabled wake, authentication, manual, and scheduled refreshes using the interval selected in Refresh.

When Codex is not connected, the Codex tab replaces quota controls with a connection card. **Sign in with browser** uses the Codex app-server's provider-generated URL and completion event. **Sign in with Codex CLI…** opens Terminal visibly, runs the located `codex login`, polls `codex login status`, and confirms the account with `account/read`. Neither path reads or stores credentials, and successful confirmation triggers one quota refresh. The bottom action row's **Refresh Now**, **Notification Settings**, **Preferences…**, and **Quit Codex Usage Monitor** commands remain available in both connected and unavailable states.

When independent `codex login` completes while the monitor is disconnected, the connection controller silently reads the same Codex home on application activation and at most every 30 seconds while disconnected. It uses read-only `account/read`, does not inspect credential files, and does not add a second quota schedule. Isolated user acceptance observed both triggers; exact authentication-refresh count, repeated-event coalescing, negative, logout, sleep/wake, and teardown checks remain unobserved.

Connection verification on 2026-07-13 covered Swift compilation, a confirmed live one-shot quota read, signed-bundle startup, absence of a new crash report, and process survival with an isolated empty `CODEX_HOME`. User-reported manual acceptance also confirmed the disconnected menu and successful browser/CLI sign-in transitions. Verification does not log out or modify the user's active Codex account automatically.

Native notification controls also cover confirmed resets, reset failures verified by two post-reset reads, data older than 15 minutes, and extended update interruptions. The interruption notice appears once on the third consecutive unsuccessful refresh, cautiously says the user may be disconnected, and is not repeated during the same persisted episode; overlapping stale-data notices are suppressed until recovery. Missing Codex CLI and signed-out states use the dedicated connection UI instead. The app does not implement its own quiet-hours schedule; use macOS Focus or notification settings for time-based silencing. No notification stores raw provider errors or changes the probe's read-only safety boundary.

Turning off **Enable quota notifications** greys every subordinate warning control without erasing its stored value. Notification authorization status and **Open Notification Settings…** remain available so denied macOS permission can still be repaired.

The native app reports macOS notification authorization separately from its alert preference. When system permission is denied, it links to Notification Settings because macOS does not repeat the original permission prompt. Both the popover and separate Settings window observe the same state.

The former separate Dashboard-window plan was replaced on 2026-07-28 by a **Token activity** card in each provider tab of the existing menu popover, now implemented. While the app runs, it automatically performs field-scoped, zero-token-cost reads of known provider session roots and rebuilds an in-memory-only activity index after every launch. The dynamic-height **This Mac · observed** card uses hoverable 30-minute completion-time bars and lists provider-native token rows, Requests, the top three short model groups plus counted Other, and Last Request across all observed dates. It distinguishes missing records, unsafe reads, and a valid zero day, remains independent of quota availability, and never collects conversation content or paths.

Reconciliation is the substance of this feature, not charting. Codex cumulative counters replay, reset, and interleave across forks; Claude repeats one assistant message as cumulative streaming chunks and can replay it again inside a subagent transcript. Both are collapsed before anything is aggregated. A record that claims usage but cannot be trusted makes that provider's activity unavailable rather than producing a plausible number.

The card's tallest state currently exceeds a typical laptop screen height in the non-scrolling popover; that layout decision is open and recorded in the implementation plan.
