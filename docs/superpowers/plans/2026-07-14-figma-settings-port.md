# High-Fidelity Settings Port Implementation Plan

**Status (2026-07-14): implemented historical stage; navigation superseded.** This 820 × 580 top-tab version passed signed Light inspection, then the user explicitly replaced its navigation contract with the strict global-sidebar revision in `2026-07-14-figma-settings-global-sidebar.md`. Measurements and evidence below describe the historical first Figma stage, not the current shell.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` inline. Do not create or run automated tests; verify with warnings-as-errors compilation, the signed app bundle, and direct Settings-window inspection.

**Goal:** Port the imported Figma-generated Preferences design into the native macOS Settings window without changing business logic, state ownership, persistence, collectors, scheduling, notifications, connection flows, or menu behavior.

**Architecture:** Treat `High-fidelity macOS menu UI/src/components/PreferencesWindow.tsx` and `src/imports/image-3.png` as visual specifications only. Keep shared `AppSettings`, `QuotaViewModel`, and all actions/bindings. Extend the shared Settings layout with semantic grouped surfaces and an optional 220-point contextual panel so every tab can adopt the visual hierarchy without duplicating application logic.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit semantic colors, SF Symbols, existing Combine-backed observable state; no third-party dependencies or imported React/CSS runtime.

## Global Constraints

- Scope is Settings only. Do not port `MenuBarDropdown`, widgets, Watch surfaces, or menu-bar chrome.
- Preserve every existing control, binding, action, disabled state, recovery path, conditional state, and privacy boundary.
- Omit generated fake or deferred behaviors: Start Minimized, Show in Menu Bar, Open on Update, notification summaries, quiet hours, cache reset, export, and copy logs.
- Use `SettingsPage`, `SettingsSection`, `SettingsLabeledRow`, `SettingsDescription`, and centralized `SettingsLayoutMetrics`.
- Keep long content scrollable and use semantic system foreground/background styles in Light and Dark appearance.
- Use native controls and SF Symbols. No bitmap assets are required for this Settings slice.
- Do not add or run automated tests.

---

### Task 1: Establish the high-fidelity shared Settings shell

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSectionSidebar.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsContextPanel.swift`

**Interfaces:**
- Produces: an 820 × 580 Settings window; 180-point section/provider sidebar; scrollable center detail; optional 220-point context panel; semantic grouped sections.
- Consumes: existing top-tab and per-page content without changing state interfaces.

- [x] Centralize imported dimensions, card radius, page insets, sidebar width, and context-panel width in `SettingsLayoutMetrics`.
- [x] Restyle `SettingsSection` as a subtle grouped surface with a compact section label, semantic background, hairline border, and explicit padding.
- [x] Left-align regular labeled rows and keep controls bounded inside the center column; retain stacked compact behavior.
- [x] Add reusable context/detail containers without introducing another navigation owner.
- [x] Set the native Settings content frame to 820 × 580 and preserve the top `TabView`.

### Task 2: Add live visual context panels

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsContextView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsContextView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsContextView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/StatusSettingsContextView.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState`, `SettingsStatus`, `AppSettings`, refresh schedule state, connection state, and static privacy inventory.
- Produces: presentation-only miniature menu status, notification examples, refresh state, connection/privacy/diagnostic summaries.

- [x] Build a live General preview from the existing menu-label presentation and displayed quota record; never hardcode account quota values.
- [x] Build Notification previews that react only to existing notification preferences and are explicitly sample previews, not delivery history.
- [x] Build Refresh status from existing schedule/display timestamps and state.
- [x] Build compact Agents, Data & Privacy, and Diagnostics summaries from already-exposed state only.
- [x] Use text/icon distinctions in addition to color for accessibility.

### Task 3: Integrate every Settings tab without changing behavior

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift`
- Modify only for presentation text/icon metadata: section/provider enum files in `Settings/`.

**Interfaces:**
- Preserves: all current bindings, actions, section selections, notification authorization recovery, sign-in actions, manual refresh, and read-only privacy/diagnostic content.
- Produces: consistent center cards and right-side context across all six top tabs.

- [x] Wire General, Notifications, and Refresh through the three-column layout with their current lower section sidebars.
- [x] Wire Agents through the same layout while retaining provider selection and connection actions.
- [x] Wrap Data & Privacy and Diagnostics in center-plus-context layout without inventing actions.
- [x] Keep every explanatory/recovery string wrapping at callout size or larger.
- [x] Confirm no generated-only setting or destructive/export action entered the native app.

### Task 4: Document and verify the Settings-only port

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-port.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`

- [x] Run `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors`.
- [x] Run `CodexUsageMonitor/Scripts/build-app.sh`, strict code-signature verification, and `Info.plist` linting.
- [ ] Inspect the signed Settings window at 820 × 580 in Light and Dark appearance. Light passed across all tabs; Dark remains manual.
- [ ] Open all six tabs and every affected sidebar selection; check long/conditional states, clipping, wrapping, scrolling, disabled controls, and top-tab stability. All six default tab states passed in Light; every sidebar and manufactured conditional state remains manual.
- [x] Compare the native result directly with `High-fidelity macOS menu UI/src/imports/image-3.png`, recording deliberate macOS/architecture adaptations.
- [x] Run `git diff --check` and record any manual visual limitation rather than claiming unobserved states.

## Verification evidence

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors` passed after the final context-rail correction.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh` produced and signed `CodexUsageMonitor/.build/CodexUsageMonitor.app`.
- `codesign --verify --deep --strict --verbose=2` reported the app valid on disk and satisfying its designated requirement; `plutil -lint` reported the bundled `Info.plist` OK.
- `git diff --check` emitted no output; a trailing-whitespace scan also returned no matches in the Settings and documentation files touched by this port.
- A separately launched audit instance opened the actual signed Settings scene at 820 × 580. General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics were directly inspected in Light appearance. No leading labels clipped, no controls crossed the trailing edge, descriptions wrapped, long Data & Privacy content remained scrollable, and the top tab bar did not move.
- The initial signed comparison showed `underPageBackgroundColor` rendering the right context rail as a dark disabled-looking region. `SettingsContextPanel` now uses adaptive `windowBackgroundColor`; the rebuilt Notifications page was directly re-inspected and matched the reference hierarchy more closely.
- The generated global sidebar/search was deliberately not copied: `SettingsView` remains the sole owner of the full-width native top tabs, with section/provider navigation confined to the lower content region. Generated fake controls and actions were omitted.
- Dark and full conditional-state automation remains manual. When macOS Accessibility stopped reliably distinguishing the temporary instance's shared Settings scene from the pre-existing app, automation stopped. The persisted appearance value was confirmed unchanged as `system`; only temporary PIDs 73820 and 75186 were closed, and pre-existing PID 69263 remained running.

## Self-review

- Spec coverage: Settings is the only imported surface; all six native tabs receive the shared visual treatment and contextual hierarchy.
- Architecture: generated React state is discarded; existing Swift state/actions remain the only behavior source.
- Scope control: no menu, Dashboard, provider, storage, notification-policy, or refresh-scheduling behavior changes.
- Historical native adaptation: this stage did not copy the global sidebar/search. The later user-directed revision supersedes that choice and makes the global sidebar authoritative.
- Verification: repository-required signed-app visual acceptance replaces prohibited generated tests.
