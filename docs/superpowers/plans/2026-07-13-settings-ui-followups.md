# Settings UI Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Notifications, General, and Agents Settings with per-threshold warning choices, native disabled-state hierarchy, working launch/appearance/shortcut preferences, and an Agents sidebar that occupies only the content area below the Settings tab bar.

**Architecture:** `AppSettings` remains the persisted preference owner. Notification delivery consumes a typed set of enabled fixed thresholds; a small launch-at-login controller owns `SMAppService`; Settings applies one appearance preference to app-owned windows; app-local shortcuts read one persisted enablement flag. `SettingsView` continues to own the full-width top `TabView`, while `AgentsSettingsView` becomes an inner content-only split that cannot affect the top tab bar.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, ServiceManagement, UserNotifications, Foundation `UserDefaults`; no third-party dependencies.

## Global Constraints

- Implement on `feature/settings-ui-followups` after `feature/codex-connection` is merged and `main` is updated.
- Do not add or run automated tests. Verify with compilation, a signed app build, preference relaunch checks, notification inspection, and manual Settings acceptance.
- Keep the fixed remaining-quota thresholds at exactly 50%, 25%, 10%, and 5%; do not add arbitrary threshold entry.
- Each threshold preference applies to both the five-hour and weekly quota lanes.
- Turning off **Enable quota notifications** disables delivery and greys all subordinate controls without erasing their stored choices.
- Keep notification authorization status and **Open Notification Settings…** usable when the master switch is off or macOS permission is denied.
- Interpret “auto login start” as the existing planned **Launch at login** preference, backed by `SMAppService.mainApp` and defaulting off.
- Appearance choices are **System**, **Light**, and **Dark**, with **System** as the default. Apply them only to app-owned windows, not native menu-bar chrome.
- Interpret “hotkeys” as app-local keyboard shortcuts, not system-wide global hotkeys. Initial scope is `Command-R` for **Refresh now**; standard macOS `Command-,` for Settings and `Command-Q` for Quit remain available and are not disabled by this preference.
- The top Settings tab bar must remain full-width and unchanged. The Agents provider sidebar begins below it and divides only the lower Agents content region.
- Preserve Codex, Claude Code, and GitHub Copilot as the visible provider list; Codex remains the only active integration.
- Keep menu-bar display controls out of this branch. The later `feature/menu-bar-display` branch adds them to General after Dashboard, using the persisted Settings patterns established here.
- Update `outline.md`, the daily-driver roadmap, `how-to.md`, and `UsageProbe/README.md` when implementation changes behavior.

---

### Task 1: Persist individual quota-warning thresholds

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/RemainingQuotaThreshold.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`

**Interfaces:**
- Produces: `RemainingQuotaThreshold`, `AppSettings.enabledQuotaThresholds`, and `AppSettings.isQuotaThresholdEnabled(_:)`.
- Consumes: the legacy `notification.thresholdWarnings` preference for one-time compatibility.

- [ ] Define `RemainingQuotaThreshold` as a `CaseIterable`, `Codable`, `Hashable`, `Identifiable`, `Sendable` enum with raw integer values `50`, `25`, `10`, and `5`, ordered from earliest to most critical.
- [ ] Persist the enabled raw values under `notification.enabledQuotaThresholds`; fresh installs default to all four thresholds enabled.
- [ ] When the new key is absent, migrate the legacy `notification.thresholdWarnings` value: legacy `false` becomes an empty set and legacy `true` or missing becomes all four thresholds.
- [ ] Keep the old key read-only for migration and stop writing it after the new set has been saved.
- [ ] Ensure toggling one threshold cannot mutate any other notification-category preference.

### Task 2: Replace the combined warning toggle and enforce visual hierarchy

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`

**Interfaces:**
- Consumes: `AppSettings.alertsEnabled`, `enabledQuotaThresholds`, notification authorization state, and the existing category/quiet-hour preferences.
- Produces: four threshold bindings and native disabled states for every subordinate notification control.

- [ ] Keep **Enable quota notifications** as the master switch and remove the single **Remaining quota warnings** category switch.
- [ ] Under a **Remaining quota** section, render four toggles with exact labels **50% remaining**, **25% remaining**, **10% remaining**, and **5% remaining**.
- [ ] Add the concise description: “Applies to both the 5-hour and weekly limits.” Do not repeat the threshold values in a second sentence.
- [ ] Disable and natively grey the threshold toggles, forecast/reset/stale/failure toggles, **Enable quiet hours**, both time pickers, and **Allow critical warnings** whenever the master switch is off.
- [ ] Preserve the existing secondary quiet-hours rule: time pickers and **Allow critical warnings** also remain disabled when quiet hours themselves are off.
- [ ] Do not reset subordinate values when the master switch changes. Re-enabling notifications restores the prior checklist selections.
- [ ] Keep authorization text and **Open Notification Settings…** outside the disabled subtree so permission recovery always works.

### Task 3: Filter quota delivery by the selected thresholds

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`

**Interfaces:**
- Consumes: `AppSettings.enabledQuotaThresholds` and trusted `QuotaPresentation` windows.
- Produces: threshold-specific delivery for both five-hour and weekly lanes using the existing deduplication keys.

- [ ] Replace the `thresholdWarningsEnabled` guard with iteration over enabled `RemainingQuotaThreshold` values.
- [ ] Skip disabled thresholds without changing the existing reset-window deduplication key format for enabled thresholds.
- [ ] Preserve trusted-data gating: cached, unconfirmed, or unavailable results never produce threshold warnings.
- [ ] Preserve 5% as critical severity and 50%/25%/10% as warning severity.
- [ ] Confirm disabling the master switch still prevents every notification category regardless of subordinate values.

### Task 4: Add working General preferences

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppearancePreference.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LaunchAtLoginController.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`

**Interfaces:**
- Produces: persisted `appearancePreference`, persisted `keyboardShortcutsEnabled`, actual launch-at-login status/action, and an app-window color-scheme mapping.
- Consumes: `SMAppService.mainApp`, the existing `QuotaViewModel`, and app-owned scene roots.

- [ ] Add **Launch at login** to General. Default off, reflect the actual `SMAppService.mainApp.status`, and show a concise inline failure without silently flipping the displayed choice.
- [ ] Add an **Appearance** picker with **System**, **Light**, and **Dark**. Persist the selection and apply it immediately to the Settings window and later app-owned Dashboard window; leave native menu-bar presentation alone.
- [ ] Add **Enable keyboard shortcuts**, default on, with the description “Allows app shortcuts such as ⌘R for Refresh now.”
- [ ] When enabled, expose `Command-R` on every app-owned **Refresh now** command. When disabled, remove that custom shortcut while leaving the button action available.
- [ ] Do not make `Command-,` or `Command-Q` conditional; they remain standard macOS behavior.
- [ ] Keep application version/build and Codex-first scope as read-only General sections below the working preferences.

### Task 5: Constrain the Agents sidebar to the lower content region

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`

**Interfaces:**
- Consumes: the outer `TabView` selection and existing provider/detail views.
- Produces: a content-only provider sidebar with stable top-tab geometry.

- [ ] Keep `SettingsView` as the sole owner of the full-width top Settings tab bar; do not nest another toolbar or title bar around it.
- [ ] Replace the Agents `NavigationSplitView` with an inner `HStack(spacing: 0)` or equivalent content-only split inside the Agents tab content.
- [ ] Render the provider `List` in a compact fixed-width sidebar of approximately 180 points, followed by a divider and a detail region that fills the remaining lower width.
- [ ] Remove `.navigationTitle` and navigation-split column behavior that can reserve or reshape space above the lower content region.
- [ ] Preserve provider selection and each existing Codex/planned-provider detail view without changing connection behavior.
- [ ] Verify switching between General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics never shifts, narrows, or overlays the top tab bar.

### Task 6: Document and manually verify the Settings follow-up

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: final behavior and manual acceptance evidence.
- Produces: current user instructions and accurate roadmap status.

- [ ] Run `swift build --package-path CodexUsageMonitor` and `Scripts/build-app.sh`; require a valid signed bundle.
- [ ] Relaunch and verify all four threshold choices persist independently and control both quota lanes.
- [ ] Verify turning the master notification switch off greys every subordinate notification control, retains its values, and leaves permission-recovery UI usable.
- [ ] Verify Launch at Login against actual macOS registration state using the signed `.app`, not the raw SwiftPM executable.
- [ ] Verify System/Light/Dark changes app-owned windows immediately and persists after relaunch.
- [ ] Verify disabling keyboard shortcuts removes `Command-R` behavior without disabling **Refresh now**, Settings, or Quit.
- [ ] Verify the Agents sidebar begins below the unchanged full-width tab bar and divides only the lower content region.
- [ ] Record all behavior and any remaining manual limitations in the plan, `outline.md`, `how-to.md`, and `UsageProbe/README.md`.

## Self-review

- Spec coverage: separate 50/25/10/5 choices, master disabled hierarchy, Launch at Login, System/Light/Dark, shortcut enablement, and lower-only Agents sidebar each have explicit implementation and acceptance steps.
- Migration safety: the legacy combined threshold switch maps deterministically to the new set without unexpectedly enabling warnings a user had disabled.
- Scope control: no arbitrary thresholds, per-lane threshold matrices, global hotkeys, provider expansion, Figma redesign, Dashboard work, export/delete, or account switching are included.
- Type consistency: `AppSettings` owns persisted choices; `QuotaNotifier` consumes typed thresholds; `SettingsView` owns the top tab bar; `AgentsSettingsView` owns only its lower inner split.
- Verification constraint: no automated tests or test commands are added; compilation, signed builds, relaunch checks, notification behavior, and manual layout review are the acceptance evidence.
