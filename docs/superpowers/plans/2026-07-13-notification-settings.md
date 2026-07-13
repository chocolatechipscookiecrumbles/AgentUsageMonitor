# Notification Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` task by task. Do not create or run automated tests.

**Goal:** Give the Codex monitor a separate Settings window whose warning controls persist and directly govern notification decisions.

**Architecture:** `AppSettings` is the deep persisted settings module. `QuotaNotifier` consumes it when evaluating a `QuotaRecord`; views never write notifier internals. The first slice governs existing notifications, followed by monitor-derived operational warnings and quiet-hours policy.

**Tech Stack:** Swift 6.2, SwiftUI Settings scene, Combine, UserDefaults, UserNotifications.

## Global constraints

- Fixed quota thresholds remain 50%, 25%, 10%, and 5%.
- Notification permission is requested only after the user explicitly enables the master switch.
- Forecast alerts require confirmed live data and medium/high confidence.
- Never notify from raw provider text or persist raw provider errors.
- Do not generate or run automated tests.
- Update `how-to.md`, `UsageProbe/README.md`, `outline.md`, and this plan with behavior changes.
- Notification decisions may inspect normalized monitoring outcomes, but notification UI must consume the provider-neutral `QuotaDisplayState` defined in the daily-driver roadmap; do not create a competing freshness model in Settings or the popover.

### Task 1: Persist notification preferences

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`

**Interface:** `AppSettings` publishes a master enable flag plus threshold, forecast, and reset-credit-expiry warning flags. `QuotaNotifier` receives one `AppSettings` instance.

- [x] Store notification preferences in `UserDefaults`, defaulting category switches on and the master authorization-backed switch off.
- [x] Gate each existing notification path through its matching preference.
- [ ] Verify a fresh Swift build and manually confirm settings persist after relaunch.

### Task 2: Add the Settings window and notification screen

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interface:** A single macOS Settings scene opens from the popover or `Command-,`; its switches update the same settings instance used by the notifier.

- [x] Add a separate Settings window containing the notification master switch and working category switches.
- [x] Add a Settings action above Quit in the popover.
- [x] Explain that thresholds are fixed at 50%, 25%, 10%, and 5%.
- [ ] Build the app bundle and manually verify repeated opens focus one Settings window.

### Task 3: Add operational warning events

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`

- [x] Detect confirmed reset completion by a plausible reset-timestamp transition plus replenished quota.
- [x] Detect reset failure only after the scheduled reset and a confirming retry.
- [x] Warn when confirmed data becomes stale and when consecutive refresh failures reach the policy threshold.
- [x] Persist separate enable switches for reset, stale-data, and repeated-failure warnings.
- [ ] Verify decision paths through read-only observation and documented manual acceptance; do not manufacture quota changes.

### Task 4: Add quiet hours

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`

- [x] Add optional local-time start/end controls and an “Allow critical warnings” switch.
- [x] Treat 5%-remaining and reset-failed warnings as critical; defer other warnings during quiet hours.
- [x] Handle ranges crossing midnight and daylight-saving changes using Calendar rather than fixed epoch arithmetic.
- [ ] Verify both same-day and overnight quiet-hour configurations manually.

### Defect correction: notification authorization controls

- [x] Re-sign the assembled app after installing `Info.plist` so macOS sees the stable `com.david.codex-usage-monitor` notification identity.
- [x] Subscribe the popover state to the shared persisted setting so Settings and popover toggles remain synchronized.
- [x] Model macOS authorization separately from the persisted app preference (`not-determined`, `authorized`, `denied`, or `unavailable`) instead of silently collapsing every result into an off toggle.
- [x] When permission is denied, explain that macOS will not prompt again and provide an **Open Notification Settings…** action in both Settings and the popover.
- [x] Make the popover **Settings…** action select the Notifications tab, activate the app, and focus the existing Settings window.
- [ ] Rebuild, relaunch, and confirm macOS permission can be requested and both toggles update together.

### Defect correction: conditional popover content overlap

- [x] Record the reproduction: with app notifications disabled, the conditional authorization guidance increased menu content height and **Last refresh** overlapped the **Settings…** action.
- [x] Record the rejected correction: forcing a window-style `MenuBarExtra` and explicit `VStack` prevented the overlap but changed **Refresh now**, **Settings…**, and **Quit Codex Usage Monitor** from native inline menu commands into panel buttons.
- [x] Restore native menu presentation and the transparent root `Group`, without applying container padding, a fixed width, or text expansion modifiers to native menu rows.
- [x] Keep the denied-authorization explanation in a concise standalone row, followed by the inline **Open Notification Settings…** command.
- [ ] Rebuild and visually verify both authorized and denied-notification states: rows must not overlap, and all menu actions must remain inline.

### Task 5: Document and close the branch

**Files:**
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`
- Modify: `outline.md`

- [x] Document every warning category, fixed thresholds, permission behavior, and quiet-hours semantics.
- [x] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`; expected result is `Build complete!`.
- [x] Run `git diff --check`; expected result is no output and exit code 0.
