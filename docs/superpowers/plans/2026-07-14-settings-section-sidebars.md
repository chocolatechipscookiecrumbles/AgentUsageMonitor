# Settings Section Sidebars Implementation Plan

**Recovered status (2026-07-16): historical implementation, superseded by the global Settings sidebar.** General and Notifications were directly inspected in this earlier layout stage, but its remaining unchecked acceptance rows do not describe the current global-sidebar UI. Restored from `wip/figma-followups-2026-07-15` for provenance; do not resume it as an active implementation plan without re-scoping it against current `main`.

> **For agentic workers:** This is a historical plan, not an active execution queue. If a current replacement is scoped, add focused automated coverage for deterministic seams and verify native layout separately with warnings-as-errors compilation, the signed app bundle, and direct Settings-window acceptance.

**Goal:** Give General, Notifications, and Refresh an Agents-style lower-content sidebar whose rows are the existing section headings and whose detail pane shows one selected section at a time.

**Architecture:** `SettingsView` continues to own the full-width top `TabView`. A reusable `SettingsSectionSidebar` owns only the selected tab's lower `List`, divider, and detail region; each affected tab owns a typed section enum and renders existing controls through `SettingsPage` and `SettingsSection` without moving persistence or actions.

**Tech Stack:** Swift 6.2, SwiftUI, native macOS `List`, existing `SettingsLayout` components.

## Global Constraints

- Preserve the 680 × 520 Settings frame and full-width top tab bar.
- Keep provider navigation and new section navigation inside the lower tab content only.
- Preserve all existing controls, disabled-state gates, actions, bindings, copy, and privacy boundaries.
- Use native SwiftUI controls and adaptive system colors.
- Keep every detail page vertically scrollable.
- Historical verification relied on compilation and signed-app acceptance; any current replacement follows the repository's current automated-regression policy.
- Preserve unrelated user changes.

### Task 1: Add reusable section-sidebar navigation

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSectionSidebar.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`

**Interface:**

```swift
struct SettingsSectionSidebar<Selection: Hashable, SidebarLabel: View, Detail: View>: View {
    init(
        items: [Selection],
        selection: Binding<Selection>,
        @ViewBuilder sidebarLabel: @escaping (Selection) -> SidebarLabel,
        @ViewBuilder detail: @escaping (Selection) -> Detail
    )
}
```

- [x] Centralize the 190-point inner-sidebar width in `SettingsLayoutMetrics`.
- [x] Render a native sidebar `List`, divider, and full-size detail pane without adding a nested top toolbar.
- [x] Give every sidebar item an explicit selection tag.

### Task 2: Convert Notifications sections

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsSection.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`

- [x] Add **Notifications**, **Remaining Quota**, and **Other Warnings** as the three sidebar items.
- [x] Preserve notification authorization recovery outside disabled subordinate settings.
- [x] Preserve the master switch and all existing category bindings exactly.

### Task 3: Convert General sections

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsSection.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`

- [x] Add Startup, Appearance, Keyboard Shortcuts, Menu Bar, Application, and Current Scope as sidebar items.
- [x] Preserve Launch at Login refresh behavior and every existing preference binding.
- [x] Keep the selected detail vertically scrollable and wrapping.

### Task 4: Convert Refresh sections

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsSection.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`

- [x] Add Current Policy and Latest Collection as sidebar items.
- [x] Preserve live scheduling/status values, the refresh picker, and manual refresh action.

### Task 5: Verify and document

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`

- [x] Compile with warnings as errors.
- [x] Build and sign the app with `CodexUsageMonitor/Scripts/build-app.sh`.
- [x] Inspect the visible General and Notifications sidebar layouts at 680 × 520 for scrolling, clipping, disabled controls, and top-tab stability.
- [ ] Open every remaining individual sidebar item, including Refresh, and inspect its long/conditional states.
- [x] Check Light and Dark appearance or record the uninspected appearance as a limitation. The user confirmed both appearances work on 2026-07-14; individual section and conditional-state coverage remains manual.
- [x] Run strict signature verification, plist linting, and `git diff --check`.

## Verification evidence

- Warnings-as-errors compilation passed (`Build complete! (2.58s)`).
- The signed bundle build passed (`Build complete! (2.13s)`).
- A separately identified audit bundle preserved the user-owned PID 60019. Notifications visibly showed all three requested sidebar rows and a readable Notifications detail. General visibly showed all six rows and readable Current Scope and Startup details without moving the top tabs.
- Coordinate and accessibility navigation did not reliably select the requested remaining states while the desktop was active. Audit PID 61115 was terminated; PID 60019 remained running. The user later confirmed Light/Dark behavior; Refresh and every individual section remain manual acceptance.

## Self-review

- The requested notification sidebar labels map one-to-one to the existing three section headings.
- The same pattern applies to General and Refresh without changing behavior ownership.
- The top Settings tab bar and Agents provider sidebar remain in their current scopes.
- No Dashboard, provider, notification-policy, scheduling, persistence, or menu changes are included.
