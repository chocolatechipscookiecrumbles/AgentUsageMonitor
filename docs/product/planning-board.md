# Product Planning Board

This is the centralized index for planned implementation, bug fixes, release gates, and historical plans. Update this board whenever an item's scope, status, next action, or source plan changes. Detailed requirements and verification evidence remain in the linked plan files.

Status vocabulary:

- **Active** — implementation or acceptance is currently underway.
- **Queued** — the next bounded work is understood but has not started.
- **Needs plan** — the problem is recorded, but implementation boundaries and acceptance still need a dedicated plan.
- **Deferred** — do not start without the stated decision or prerequisite.
- **Verification** — implementation exists; evidence or manual acceptance remains.
- **Historical** — retained for provenance and not an execution queue.
- **Closed** — implemented and accepted for the documented scope.

## Product follow-up coverage

This table carries the required outcome and acceptance boundary for every numbered item in [Product Follow-ups](follow-ups.md). Keep the detailed evidence and design notes in that source file, but update both locations when a follow-up changes.

| Follow-up | Board placement | Required outcome and acceptance boundary |
| --- | --- | --- |
| [1. Network-aware refresh scheduling and diagnostics](follow-ups.md#1-network-aware-refresh-scheduling-and-diagnostics) | Feature — **Needs plan** | Observe connectivity, interface, offline/online, and restoration changes; report only evidence-supported states; refresh immediately after restoration without duplicates while `QuotaMonitor` remains authoritative. |
| [2. Automatic recovery from interrupted sign-in](follow-ups.md#2-automatic-recovery-from-interrupted-sign-in-flow) | Bug fix — **Deferred** | The [dedicated recovery plan](../superpowers/plans/2026-07-17-interrupted-signin-recovery.md) returns cancelled, failed, or timed-out Browser/CLI attempts to a usable disconnected state with clear status, restores both sign-in actions, and lets the existing watcher reconcile an independent login. Do not implement until explicitly resumed. |
| [3. Menu popover layout regression](follow-ups.md#3-menu-popover-layout-regression) | Bug fix — **Needs plan** | Prevent Reset copy from overlapping Quota Alerts using native spacing and truncation; preserve readability for supported narrow widths, localization, and Dynamic Type. |
| [4. System appearance transition](follow-ups.md#4-finish-system-appearance-transition-implementation) | Bug fix — **Closed** | Keep the entire Settings hierarchy synchronized through Light, Dark, System, and live macOS transitions with no stale borders, dividers, cards, or other mixed-appearance regions. |
| [5. Simplify the General Settings context rail](follow-ups.md#5-simplify-general-settings-context-rail) | Feature — **Queued** | The [Figma Settings Design Completion plan](../superpowers/plans/2026-07-17-figma-settings-design-completion.md) removes **Current Label**, **Current Scope**, and the duplicate General-page Preview while preserving the current native theme and making one larger full-width Context Rail preview authoritative. Do not advance this row to Verification until direct signed-app rail and conditional-state acceptance is observed. |
| [6. Dedicated Permissions Settings destination](follow-ups.md#6-dedicated-permissions-settings-destination) | Feature — **Needs plan** | Centralize permissions the app actually uses, each with current status, purpose, limitation guidance, and a direct native Settings action; include Notifications, Accessibility, and Login Items, and add Automation, Screen Recording, or Full Disk Access only if future functionality requires them. Never bypass macOS permission workflows. |
| [7. Richer refresh failure explanation](follow-ups.md#7-future-enhancement-richer-refresh-failure-explanation) | Feature — **Needs plan** | Explain why a refresh failed using structured observable causes, supporting evidence, suggested recovery, and confidence where causes overlap; do not present unsupported network, provider, authentication, CLI, in-progress, or rate-limit guesses as fact. |
| [8. Detect an external Codex login while disconnected](follow-ups.md#8-detect-an-external-codex-login-while-disconnected) | Bug fix — **Verification** | The controller-owned 30-second/activation [external-login detection plan](../superpowers/plans/2026-07-17-external-codex-login-detection.md) is implemented; isolated user acceptance observed both triggers. Keep custom `CODEX_HOME`, teardown, credential privacy, and one authentication refresh subject to the remaining unobserved coalescing/negative-path checks. |

## Feature board

| Item | Status | Next action | Primary links |
| --- | --- | --- | --- |
| Dashboard window and analytics | **Deferred** | Resume only on explicit direction; revalidate its partial historical implementation against `main` first. | [Dashboard plan](../superpowers/plans/2026-07-14-dashboard.md), [roadmap phase 7](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#7-featuredashboard) |
| Stable Settings regions and shared native switches | **Queued** | Implementation and static checks are complete. Do not advance to Verification until the signed app is directly inspected at 680 × 560 hidden and 891 × 560 visible, with stable left regions, native switches, VoiceOver, and conditional states. | [design-completion plan](../superpowers/plans/2026-07-17-figma-settings-design-completion.md), [provider follow-ups Task 1](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-1-stabilize-settings-region-geometry-and-switch-styling), [SettingsView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift) |
| Indexed Settings search and exact-control routing | **Deferred** | Implement only after Task 1 geometry is stable; preserve Search-First Focus and Reduce Motion behavior. | [provider follow-ups Task 2](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-2-add-indexed-setting-search-and-exact-control-routing), [SettingsNavigationSidebar.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsNavigationSidebar.swift) |
| Per-provider, per-quota-window warning preferences | **Deferred** | Migrate legacy Codex preferences, then scope threshold/forecast/reset delivery keys by provider and window. | [provider follow-ups Task 3](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-3-split-quota-warning-preferences-by-window-and-provider), [AppSettings.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift) |
| Provider identity in usage notifications | **Deferred** | Use provider/window copy as the baseline; do not add unofficial artwork. | [provider follow-ups Task 4](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-4-identify-the-provider-in-usage-notifications), [QuotaNotifier.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift) |
| Reversible app-local agent Disconnect | **Deferred** | Implement only for adapters with a real connection controller and monitoring lifecycle contract. | [provider follow-ups Task 5](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-5-add-reversible-app-local-disconnect-per-supported-agent), [CodexConnectionController.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift) |
| Supported-agent selector and paired-agent context blocks | **Deferred** | Wait for another supported adapter; do not render speculative provider behavior. | [provider follow-ups Task 6](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector), [AgentsSettingsView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift) |
| Preferred/effective Menu Bar Agent and failover policy | **Deferred** | Preserve the extraction boundary and implement only with real multi-provider capability. | [provider follow-ups Task 7](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-7-add-menu-bar-agent-selection-and-preserve-the-extraction-boundary), [MenuBarStatusLabel.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift) |
| Network-aware refresh scheduling and diagnostics | **Needs plan** | Separate evidence-based path observation from provider reachability; keep `QuotaMonitor` authoritative and coalesce recovery refreshes. | [product follow-up 1](follow-ups.md#1-network-aware-refresh-scheduling-and-diagnostics), [QuotaMonitor.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift), [RefreshDiagnosticsStore.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshDiagnosticsStore.swift) |
| Simplified General context rail | **Queued** | Implementation keeps one larger full-width menu-bar preview and removes Current Label, Current Scope, and the duplicate General-page Preview. Do not advance to Verification until both rail states and live/conditional content are inspected in the signed app. | [design-completion plan](../superpowers/plans/2026-07-17-figma-settings-design-completion.md), [GeneralSettingsContextView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsContextView.swift), [GeneralSettingsView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift) |
| Dedicated Permissions Settings destination | **Needs plan** | Define only permissions the app actually uses, with status, purpose, and native System Settings links. | [product follow-up 6](follow-ups.md#6-dedicated-permissions-settings-destination), [NotificationSettingsView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift), [LaunchAtLoginController.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LaunchAtLoginController.swift) |
| Evidence-rich refresh failure explanation | **Needs plan** | Build on typed failure classifications and display evidence/confidence without guessing network or provider causes. | [product follow-up 7](follow-ups.md#7-future-enhancement-richer-refresh-failure-explanation), [provider-plan diagnosis boundary](../superpowers/plans/2026-07-14-settings-provider-followups.md#global-constraints), [QuotaPresentation.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaPresentation.swift) |
| True per-second native-menu countdown | **Deferred** | Keep the event-driven absolute-time row. A future countdown requires a product reason, ADR, and signed prototype proving fixed geometry and correct scrolling/highlights without a per-second SwiftUI `MenuBarExtra` invalidation. | [refresh-row plan Task 5](../superpowers/plans/2026-07-14-native-menu-refresh-row.md#task-5-gate-any-future-true-live-countdown-behind-an-architecture-decision), [repository guardrails](../../AGENTS.md#native-menu-dynamic-update-guardrails) |
| Other Figma surfaces | **Deferred** | Menu popover, Dashboard, widgets, and Watch require separate direction and approved screen nodes. | [roadmap phase 8](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#8-featurefigma-ui-overhaul), [Figma Settings global-sidebar plan](../superpowers/plans/2026-07-14-figma-settings-global-sidebar.md) |
| GitHub Copilot capability research/provider | **Deferred** | Begin only after the Codex daily-driver release and verify an official personal allowance path before implementation. | [later provider branches](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#later-provider-branches) |
| Claude local analytics/provider research | **Deferred** | Begin only after the Codex daily-driver release; keep quota support experimental until proven. | [later provider branches](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#later-provider-branches) |

## Bug-fix board

| Item | Status | Next action | Primary links |
| --- | --- | --- | --- |
| Native-menu scrolling/highlight displacement caused by the live countdown | **Closed** | Preserve the event-driven absolute-time repair and re-run signed pointer/scroll acceptance for any future dynamic row change. User inspection accepted the original failure path on 2026-07-17. | [accepted repair plan](../superpowers/plans/2026-07-14-native-menu-refresh-row.md), [MenuRefreshTimingPresentation.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuRefreshTimingPresentation.swift), [native-menu guardrails](../../AGENTS.md#native-menu-dynamic-update-guardrails) |
| External Codex CLI login is not detected from the disconnected stage | **Verification** | Controller-owned read-only rechecks now run on activation and at most every 30 seconds while disconnected. Isolated acceptance observed both routes, one persisted authentication refresh, and a repeated-activation check; keep failed-read, logout, sleep/wake, teardown, and cleanup verification open. A cancelled Browser flow becoming `.failed` belongs to Follow-up 2 recovery planning. | [external-login plan](../superpowers/plans/2026-07-17-external-codex-login-detection.md), [CodexConnectionController.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift), [CodexConnectionService.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionService.swift) |
| Refresh-interruption notification can be lost after failed submission | **Verification** | Manually confirm an initially failed notification submission is re-offered on a later backed-off retry, while one successful delivery suppresses duplicates for the same stable episode. | [delivery retry correction](../superpowers/plans/2026-07-14-disconnection-notification-backoff.md#authentication-classification-correction--2026-07-14), [QuotaNotifier.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift), [QuotaMonitor.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift) |
| Interrupted browser/CLI sign-in can remain stuck | **Deferred** | A dedicated plan covers sign-in-only cancellation/failure/timeout recovery, safe status copy, repeated attempts, and the existing disconnected watcher. Resume only on explicit direction. | [recovery plan](../superpowers/plans/2026-07-17-interrupted-signin-recovery.md), [product follow-up 2](follow-ups.md#2-automatic-recovery-from-interrupted-sign-in-flow), [CodexConnectionController.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift) |
| Reset copy overlaps Quota Alerts in the native menu | **Needs plan** | Reproduce in the signed app and correct native spacing/truncation without switching to a window-style popover. | [product follow-up 3](follow-ups.md#3-menu-popover-layout-regression), [QuotaWindowRow.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaWindowRow.swift), [ConnectedQuotaMenuView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift) |
| Settings System appearance transition | **Closed** | Keep manufactured conditional states in the verification board; do not reimplement the old window bridge. | [accepted appearance plan](../superpowers/plans/2026-07-15-settings-system-appearance-transition.md), [SettingsView.swift](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift) |

## Other / release and verification board

| Item | Status | Next action | Primary links |
| --- | --- | --- | --- |
| Native-menu repair signed-app acceptance | **Closed** | The signed connected/scheduled row and original pointer/scroll regression are accepted. Keep the unmanufactured conditional states recorded as limitations, not inferred coverage. | [repair Task 4](../superpowers/plans/2026-07-14-native-menu-refresh-row.md#task-4-perform-signed-native-menu-visual-and-interaction-acceptance) |
| Seven-calendar-day Codex reliability observation | **Verification** | Record outcome counts, foreground cadence, overlap, and forecast behavior before release. | [reliability Task 5](../superpowers/plans/2026-07-13-codex-reliability-hardening.md#task-5-run-and-review-the-one-week-hardening-period) |
| Notification permission/persistence/natural-event acceptance | **Verification** | Exercise real permission and natural warning paths without manufacturing quota consumption. | [notification plan](../superpowers/plans/2026-07-13-notification-settings.md), [interruption manual matrix](../superpowers/plans/2026-07-14-disconnection-notification-backoff.md#task-5-verify-notification-restraint-and-recovery-manually) |
| Menu-bar Appearance/Show acceptance | **Verification** | Check both appearances/value modes, immediate refresh synchronization, one scheduled interval, relaunch persistence, maximum width, cached/missing lanes, and VoiceOver. | [menu-bar display Task 5](../superpowers/plans/2026-07-13-menu-bar-display.md#task-5-document-and-manually-verify-the-dynamic-display) |
| Settings follow-up acceptance | **Verification** | Check threshold persistence, disabled hierarchy, Launch at Login, shortcuts, and current global-sidebar geometry in the signed app. | [Settings follow-up Task 6](../superpowers/plans/2026-07-13-settings-ui-followups.md#task-6-document-and-manually-verify-the-settings-follow-up) |
| Settings manufactured conditional states | **Verification** | Inspect disabled notifications, missing permission/connection guidance, absent quota values, and long status strings. | [appearance plan remaining acceptance](../superpowers/plans/2026-07-15-settings-system-appearance-transition.md#remaining-manual-acceptance) |
| Codex daily-driver release | **Deferred** | Close active correctness work, finish reliability evidence, reconcile documentation, build the signed app, and execute the release checklist. | [roadmap phase 9](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#9-releasecodex-daily-driver) |
| Planning-document reconciliation | **Closed** | Keep this board and the authoritative roadmap synchronized whenever an item's status, scope, or source plan changes. | [authoritative roadmap status](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md#authoritative-plan-status--reconciled-2026-07-17), [product follow-ups](follow-ups.md), [outline](../../outline.md) |

## Plan coverage index

Every implementation plan currently in `docs/superpowers/plans` is indexed below, including completed or superseded work that should not be mistaken for an active queue.

### Active or decision-gated

- [Codex Daily-Driver Roadmap](../superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md) — authoritative sequence and release gates.
- [Native Menu Refresh Row](../superpowers/plans/2026-07-14-native-menu-refresh-row.md) — accepted repair; a true live countdown remains decision-gated.
- [Dashboard](../superpowers/plans/2026-07-14-dashboard.md) — deferred by user direction.
- [Settings and Provider Follow-ups](../superpowers/plans/2026-07-14-settings-provider-followups.md) — documentation only; split before implementation.
- [Codex Reliability Hardening](../superpowers/plans/2026-07-13-codex-reliability-hardening.md) — implementation complete, observation gate open.
- [Disconnection Notification Backoff](../superpowers/plans/2026-07-14-disconnection-notification-backoff.md) — one delivery-durability correction and manual restraint evidence remain.
- [External Codex Login Detection](../superpowers/plans/2026-07-17-external-codex-login-detection.md) — implemented; isolated interval and activation observations are recorded, with bounded manual checks remaining.
- [Interrupted Browser and CLI Sign-In Recovery](../superpowers/plans/2026-07-17-interrupted-signin-recovery.md) — deferred by user direction; no implementation has started.
- [Figma Settings Design Completion](../superpowers/plans/2026-07-17-figma-settings-design-completion.md) — implementation and static checks complete; direct signed-app Settings acceptance remains; historical Figma branch remains reference-only.

### Implemented with verification remaining

- [Notification Settings](../superpowers/plans/2026-07-13-notification-settings.md)
- [Dynamic Menu Bar Display](../superpowers/plans/2026-07-13-menu-bar-display.md)
- [Settings UI Follow-ups](../superpowers/plans/2026-07-13-settings-ui-followups.md)
- [Settings System Appearance Transition](../superpowers/plans/2026-07-15-settings-system-appearance-transition.md) — primary regression closed; manufactured states remain.

### Completed or historical provenance

- [Codex Capability Probe](../superpowers/plans/2026-07-12-codex-capability-probe.md)
- [Codex Menu-Bar MVP](../superpowers/plans/2026-07-12-codex-menu-bar-mvp.md)
- [Quota History Foundation](../superpowers/plans/2026-07-13-quota-history-foundation.md)
- [Settings Foundation](../superpowers/plans/2026-07-13-settings-foundation.md)
- [Adaptive Refresh](../superpowers/plans/2026-07-13-adaptive-refresh.md) — implemented; the menu-row repair is accepted and a true live countdown remains decision-gated.
- [Codex Connection](../superpowers/plans/2026-07-13-codex-connection.md)
- [Compact Settings and Menu Placement](../superpowers/plans/2026-07-14-compact-settings-menu-placement.md) — visual geometry superseded; interaction history retained.
- [Settings Section Sidebars](../superpowers/plans/2026-07-14-settings-section-sidebars.md) — superseded by global navigation.
- [Figma Settings Port](../superpowers/plans/2026-07-14-figma-settings-port.md) — historical intermediate stage.
- [Figma Settings Global Sidebar](../superpowers/plans/2026-07-14-figma-settings-global-sidebar.md) — implemented current Settings shell.
