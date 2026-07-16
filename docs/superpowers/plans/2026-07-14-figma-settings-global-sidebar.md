# Figma Settings Global Sidebar Implementation Plan

**Status (2026-07-14): implementation and signed Light acceptance complete; Dark appearance and manufactured conditional states remain manual.**

**Documented follow-up:** Fixed-region geometry, indexed setting search, switch styling, scoped warning controls, provider notification identity, agent Disconnect, and the Agents selector/context redesign are planned—but not implemented—in `2026-07-14-settings-provider-followups.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. Do not create or run generated automated tests; verify with warnings-as-errors compilation, the signed app bundle, and direct Settings-window inspection.

**Goal:** Replace the native top-tab and nested-sidebar Settings navigation with the downloaded Figma Preferences layout: one global left sidebar, one full grouped page per destination, and a collapsible right preview rail.

**Architecture:** `SettingsView` becomes the sole three-column shell and continues binding navigation to `AppSettings.selectedSettingsTab`. Destination views render all of their existing sections in one `SettingsPage`; a presentation-only local Boolean controls the context rail. Existing observable state, actions, persistence, collection, scheduling, notification, connection, and privacy behavior remain unchanged.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit semantic colors, native controls, SF Symbols, existing Combine-backed observable state.

## Global Constraints

- Scope is Settings only; menu popover, Dashboard, widgets, and Watch remain deferred.
- Remove the top `TabView` and every lower section/provider sidebar from the rendered Settings hierarchy.
- Keep all six destinations in the global left sidebar and bind selection to `AppSettings.selectedSettingsTab`.
- Render each destination as one vertically scrollable page with its existing section headers and controls.
- Preserve all bindings, actions, disabled states, connection guidance, permission recovery, and privacy boundaries.
- Omit generated fake settings and actions that the native app does not implement.
- Use a 780 × 520 default content frame, a 180-point global sidebar, and a 210-point preview rail.
- Keep the preview toggle accessible by label and Help text; collapsing it must expand the center content without changing saved preferences.
- Do not add or run automated tests.

---

### Task 1: Replace Settings navigation with the Figma global shell

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsTab.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsNavigationSidebar.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift`

**Interfaces:**
- Consumes: `Binding<SettingsTab>`, existing `QuotaViewModel`, `AppSettings`, `LaunchAtLoginController`.
- Produces: one 780 × 520 three-column Settings shell with searchable global navigation and a collapsible preview rail.

- [x] Add Figma-aligned global navigation rows, semantic icon colors, and native search filtering.
- [x] Add the selected-page title header and accessible preview toggle at the top right.
- [x] Route all six destinations and previews from one shell without `TabView`.
- [x] Animate only the preview rail transition and respect Reduce Motion.

### Task 2: Flatten each destination into one grouped page

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift`
- Delete: obsolete lower-navigation/container files after references are removed.

**Interfaces:**
- Preserves: all existing settings bindings, refresh/sign-in actions, disabled-state gates, and read-only status content.
- Produces: full pages separated by existing `SettingsSection` headers.

- [x] Show every General, Notifications, and Refresh section on its destination page.
- [x] Show Codex and planned agents as grouped sections on one Agents page while keeping connection actions.
- [x] Let Data & Privacy and Diagnostics rely on the shell-owned preview rail.
- [x] Remove rendered and dead lower-sidebar navigation types.

### Task 3: Reconcile documentation and verify the signed app

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-port.md`
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-global-sidebar.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `AGENTS.md`

- [x] Compile with warnings as errors and build the signed app.
- [x] Verify the signature, bundled plist, Settings guardrails, and diff hygiene.
- [x] Inspect all six destinations at 780 × 520 and exercise the preview expanded and collapsed states.
- [x] Record any Light/Dark or conditional-state limitation without claiming unobserved coverage.

## Verification Evidence

- `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors` completed successfully with Xcode's Swift toolchain. The first final attempt was blocked only by the managed sandbox denying Swift's module cache; the permitted normal-cache rerun passed.
- `CodexUsageMonitor/Scripts/build-app.sh` completed and produced the signed app at `CodexUsageMonitor/.build/CodexUsageMonitor.app`.
- `codesign --verify --deep --strict --verbose=2` passed, and the bundled `Info.plist` passed `plutil -lint`.
- The Settings guardrail scan found no top-level `Form`, direct `LabeledContent`, `TabView`, `.tabItem`, or transparent spacer pattern in the Settings source. `git diff --check` passed.
- A separately launched signed audit instance opened at a 780 × 520-point content size. General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics were each opened directly in the global sidebar and inspected in Light appearance. Labels and descriptions remained readable, pickers stayed bounded, section spacing stayed consistent, and long pages remained vertically reachable.
- Notifications was inspected with the preview expanded, collapsed, and expanded again. The center pane resized cleanly, the header button stayed available, and the selected global-sidebar destination did not move. Sidebar search was exercised with `Data` and reduced navigation to Data & Privacy without changing the selected Diagnostics page.
- The audit used temporary PID 79651 and closed only that process. Pre-existing user-owned PID 77731 remained running.
- Dark appearance was not switched because appearance is persisted and shared with the user's pre-existing app instance. Disabled notification controls, missing permission/connection guidance, absent quota values, and other manufactured conditional states were not forced because doing so would mutate user state. These remain targeted manual acceptance items; no Dark or conditional-state coverage is claimed here.

## Self-review

- Spec coverage: global sidebar, full pages, smaller window, and right-preview toggle each have an owning task.
- Architecture: navigation still uses the existing persisted `SettingsTab`; preview collapse is local presentation state.
- Scope control: no generated-only control, collector, scheduler, notification policy, persistence schema, or menu behavior changes.
- Native adaptation: macOS supplies traffic lights and title-bar chrome; the app uses native Buttons, TextField, Pickers, Toggles, and SF Symbols.
- Verification: the repository-required signed-app visual audit replaces prohibited generated UI tests.
