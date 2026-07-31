# Settings UI Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Notifications, General, and Agents Settings with per-threshold warning choices, native disabled-state hierarchy, working launch/appearance/shortcut preferences, and an Agents sidebar that occupies only the content area below the Settings tab bar.

**Architecture:** `AppSettings` remains the persisted preference owner. Notification delivery consumes a typed set of enabled fixed thresholds; a small launch-at-login controller owns `SMAppService`; Settings applies one appearance preference to app-owned windows; app-local shortcuts read one persisted enablement flag. `SettingsView` continues to own the full-width top `TabView`, while `AgentsSettingsView` becomes an inner content-only split that cannot affect the top tab bar.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, ServiceManagement, UserNotifications, Foundation `UserDefaults`; no third-party dependencies.

## Global Constraints

- Implement on `feature/settings-ui-followups`, stacked on `feature/menu-bar-display` commit `cefd57e` so the working General menu-bar controls remain intact.
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
- Keep menu-bar display controls out of this branch. The independently stacked `feature/menu-bar-display` branch adds them to General without coupling them to the remaining Settings follow-ups.
- Update `outline.md`, the daily-driver roadmap, `docs/development/operating-notes.md`, and `UsageProbe/README.md` when implementation changes behavior.

---

### Task 1: Persist individual quota-warning thresholds

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/RemainingQuotaThreshold.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`

**Interfaces:**
- Produces: `RemainingQuotaThreshold`, `AppSettings.enabledQuotaThresholds`, and `AppSettings.isQuotaThresholdEnabled(_:)`.
- Consumes: the legacy `notification.thresholdWarnings` preference for one-time compatibility.

- [x] Define `RemainingQuotaThreshold` as a `CaseIterable`, `Codable`, `Hashable`, `Identifiable`, `Sendable` enum with raw integer values `50`, `25`, `10`, and `5`, ordered from earliest to most critical.
- [x] Persist the enabled raw values under `notification.enabledQuotaThresholds`; fresh installs default to all four thresholds enabled.
- [x] When the new key is absent, migrate the legacy `notification.thresholdWarnings` value: legacy `false` becomes an empty set and legacy `true` or missing becomes all four thresholds.
- [x] Keep the old key read-only for migration and stop writing it after the new set has been saved.
- [x] Ensure toggling one threshold cannot mutate any other notification-category preference.

### Task 2: Replace the combined warning toggle and enforce visual hierarchy

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`

**Interfaces:**
- Consumes: `AppSettings.alertsEnabled`, `enabledQuotaThresholds`, notification authorization state, and the existing category preferences.
- Produces: four threshold bindings and native disabled states for every subordinate notification control.

- [x] Keep **Enable quota notifications** as the master switch and remove the single **Remaining quota warnings** category switch.
- [x] Under a **Remaining quota** section, render four toggles with exact labels **50% remaining**, **25% remaining**, **10% remaining**, and **5% remaining**.
- [x] Add the concise description: “Applies to both the 5-hour and weekly limits.” Do not repeat the threshold values in a second sentence.
- [x] Disable and natively grey the threshold and forecast/reset/stale/failure toggles whenever the master switch is off.
- [x] Do not reset subordinate values when the master switch changes. Re-enabling notifications restores the prior checklist selections.
- [x] Keep authorization text and **Open Notification Settings…** outside the disabled subtree so permission recovery always works.

### Task 3: Filter quota delivery by the selected thresholds

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`

**Interfaces:**
- Consumes: `AppSettings.enabledQuotaThresholds` and trusted `QuotaPresentation` windows.
- Produces: threshold-specific delivery for both five-hour and weekly lanes using the existing deduplication keys.

- [x] Replace the `thresholdWarningsEnabled` guard with iteration over enabled `RemainingQuotaThreshold` values.
- [x] Skip disabled thresholds without changing the existing reset-window deduplication key format for enabled thresholds.
- [x] Preserve trusted-data gating: cached, unconfirmed, or unavailable results never produce threshold warnings.
- [x] Preserve 5% as critical severity and 50%/25%/10% as warning severity.
- [x] Confirm disabling the master switch still prevents every notification category regardless of subordinate values.

### Task 4: Add working General preferences

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppearancePreference.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LaunchAtLoginController.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/RefreshNowButton.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift`

**Interfaces:**
- Produces: persisted `appearancePreference`, persisted `keyboardShortcutsEnabled`, actual launch-at-login status/action, and an app-window color-scheme mapping.
- Consumes: `SMAppService.mainApp`, the existing `QuotaViewModel`, and app-owned scene roots.

- [x] Add **Launch at login** to General. Default off, reflect the actual `SMAppService.mainApp.status`, and show a concise inline failure without silently flipping the displayed choice.
- [x] Add an **Appearance** picker with **System**, **Light**, and **Dark**. Persist the selection and apply it immediately to the Settings window and later app-owned Dashboard window; leave native menu-bar presentation alone.
- [x] Add **Enable keyboard shortcuts**, default on, with the description “Allows app shortcuts such as ⌘R for Refresh now.”
- [x] When enabled, expose `Command-R` on every app-owned **Refresh now** command. When disabled, remove that custom shortcut while leaving the button action available.
- [x] Do not make `Command-,` or `Command-Q` conditional; they remain standard macOS behavior.
- [x] Keep application version/build and Codex-first scope as read-only General sections below the working preferences.

### Task 5: Constrain the Agents sidebar to the lower content region

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`

**Interfaces:**
- Consumes: the outer `TabView` selection and existing provider/detail views.
- Produces: a content-only provider sidebar with stable top-tab geometry.

- [x] Keep `SettingsView` as the sole owner of the full-width top Settings tab bar; do not nest another toolbar or title bar around it.
- [x] Replace the Agents `NavigationSplitView` with an inner `HStack(spacing: 0)` or equivalent content-only split inside the Agents tab content.
- [x] Render the provider `List` in a compact fixed-width sidebar of approximately 180 points, followed by a divider and a detail region that fills the remaining lower width.
- [x] Remove `.navigationTitle` and navigation-split column behavior that can reserve or reshape space above the lower content region.
- [x] Preserve provider selection and each existing Codex/planned-provider detail view without changing connection behavior.
- [ ] Verify switching between General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics never shifts, narrows, or overlays the top tab bar.

### Task 6: Document and manually verify the Settings follow-up

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `docs/development/operating-notes.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: final behavior and manual acceptance evidence.
- Produces: current user instructions and accurate roadmap status.

- [x] Run `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors` and `zsh CodexUsageMonitor/Scripts/build-app.sh`; require a valid signed bundle.
- [ ] Relaunch and verify all four threshold choices persist independently and control both quota lanes.
- [ ] Verify turning the master notification switch off greys every subordinate notification control, retains its values, and leaves permission-recovery UI usable.
- [ ] Verify Launch at Login against actual macOS registration state using the signed `.app`, not the raw SwiftPM executable.
- [ ] Verify System/Light/Dark changes app-owned windows immediately and persists after relaunch.
- [ ] Verify disabling keyboard shortcuts removes `Command-R` behavior without disabling **Refresh now**, Settings, or Quit.
- [ ] Verify the Agents sidebar begins below the unchanged full-width tab bar and divides only the lower content region.
- [x] Record all behavior and any remaining manual limitations in the plan, `outline.md`, `docs/development/operating-notes.md`, and `UsageProbe/README.md`.

## Implementation and verification notes

- The branch is stacked on `feature/menu-bar-display` commit `cefd57e`; its Menu Bar General controls remain present in the compiled result.
- The legacy combined threshold key is read once for migration. The new raw-value set is written under `notification.enabledQuotaThresholds`, and notification delivery checks the selected set for confirmed live five-hour and weekly data.
- `SMAppService.mainApp` owns Launch at Login state. The controller reports enabled, not registered, approval-required, and unavailable states; it links to Login Items when user action is required and does not store a duplicate Boolean preference.
- System/Light/Dark and keyboard-shortcut preferences persist in `AppSettings`. Appearance is scoped to the Settings window; native menu-bar presentation remains system controlled. Both existing Refresh buttons use the same conditional `Command-R` component.
- The Agents provider list is a 190-point inner sidebar below the unchanged outer Settings tabs, with existing provider detail views and connection actions preserved.
- `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors`, the ad-hoc signed app build, strict code-signature validation, and `plutil -lint` passed.
- A temporary signed instance launched and remained alive through its launch refresh without a new crash report. It was launched alongside the user's existing instance so no running app was replaced.
- The reported Light → System/System-Dark mixed-appearance regression is fixed and directly accepted in the isolated signed app. Search, destination, scroll, Context Rail, and focus state survived; all six destinations were inspected in System Dark with the rail visible and hidden; explicit Light survived Settings reopen; System survived app relaunch; and the native menu stayed Dark while Settings was forced Light.
- The reciprocal System-Light transitions, live macOS appearance changes, native-menu boundary under macOS Light, and all-six-destination explicit-Light pass were subsequently completed by the user on the final signed build.
- Still manual/open: exercise each threshold and master disabled state, toggle Launch at Login from the signed app, confirm `Command-R` enable/disable behavior, and complete the manufactured conditional-state row in `2026-07-15-settings-system-appearance-transition.md`.

## July 14 visual audit follow-up

- [x] Reproduce the General, Notifications, and Refresh clipping and readability failures from screenshots of the signed app.
- [x] Replace the fragile macOS `Form` label-column behavior with one shared native SwiftUI Settings layout using consistent page margins, section spacing, and a fixed 148-point label column.
- [x] Bound picker widths so controls remain readable instead of stretching across the full window.
- [x] Promote notification permission and explanatory copy from caption-sized text to wrapping callout text.
- [x] Remove transparent section-footer spacer hacks and use explicit section spacing.
- [x] Make every preference page scroll vertically so longer content remains reachable without colliding with the window edge.
- [x] Apply the shared layout to General, Notifications, Refresh, Agents detail panes, Data & Privacy, and Diagnostics while preserving the native theme and the full-width top tab bar.
- [x] Increase the Settings content frame from 600 × 520 to 680 × 560 points for clearer tab labels and wrapped content.
- [x] Visually inspect the rebuilt signed app in dark appearance and confirm that the reported left-edge clipping is absent from General, Notifications, and Refresh.
- [x] Visually inspect Agents, Data & Privacy, and Diagnostics for consistent lower-pane/sidebar boundaries, label alignment, and readable wrapping.
- [x] Record the root causes and repository-wide prevention rules in `AGENTS.md` so later Settings work reuses the shared layout and requires signed-app visual acceptance.
- [ ] Manually inspect the same pages in Light appearance; all colors remain adaptive system styles, but the automated visual pass used the current dark system appearance.

## July 14 notification simplification follow-up

- [x] Remove app-owned quiet-hours controls from the Notifications page.
- [x] Remove the matching persistence and deferred-delivery behavior so no hidden legacy preference can suppress notifications.
- [x] Keep macOS authorization recovery and all remaining warning-category controls intact.
- [x] Document macOS Focus and notification settings as the supported scheduled-silencing mechanism.

## Self-review

- Spec coverage: separate 50/25/10/5 choices, master disabled hierarchy, Launch at Login, System/Light/Dark, shortcut enablement, and lower-only Agents sidebar each have explicit implementation and acceptance steps.
- Migration safety: the legacy combined threshold switch maps deterministically to the new set without unexpectedly enabling warnings a user had disabled.
- Scope control: no arbitrary thresholds, per-lane threshold matrices, global hotkeys, provider expansion, Figma redesign, Dashboard work, export/delete, or account switching are included.
- Type consistency: `AppSettings` owns persisted choices; `QuotaNotifier` consumes typed thresholds; `SettingsView` owns the top tab bar; `AgentsSettingsView` owns only its lower inner split.
- Verification constraint: no automated tests or test commands are added; compilation, signed builds, relaunch checks, notification behavior, and manual layout review are the acceptance evidence.
