# Settings System Appearance Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live Settings window transition completely between System, Light, and Dark without mixed AppKit/SwiftUI regions, reopening the window, or changing native menu appearance.

**Architecture:** Replace the Settings root's optional `preferredColorScheme` preference with one Settings-window-scoped AppKit appearance bridge. Explicit Light/Dark set `NSWindow.appearance` to Aqua/Dark Aqua; System clears the window override so its title bar and hosted SwiftUI hierarchy inherit the current and future macOS appearance together. Keep `AppSettings` as the persisted choice owner and keep native `MenuBarExtra` system-controlled.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Combine-backed `AppSettings`, XCTest, macOS 14+; signed-app visual acceptance at the 780 × 520 Settings size.

## Global Constraints

- Preserve **System**, **Light**, and **Dark**, with System as the default and existing persistence key `general.appearance` unchanged.
- Scope the override to the Settings `NSWindow`; do not set `NSApplication.appearance` or force native menu-bar chrome.
- System must assign `nil` to `NSWindow.appearance` so an already-open Settings window follows subsequent macOS appearance changes.
- Remove `.preferredColorScheme(settings.appearancePreference.colorScheme)` from `SettingsView`; do not retain two competing appearance owners.
- Preserve the global Navigation Sidebar, selected destination, search state, scroll state, Context Rail visibility, focus, window dimensions, controls, and semantic colors.
- Do not patch individual backgrounds, cards, borders, or text colors to conceal the mixed state.
- Build the signed app and visually inspect every affected region; source inspection and isolated harnesses are diagnostic evidence only.

---

### Task 1: Preserve the root-cause evidence and acceptance boundary

**Files:**
- Modify: `docs/superpowers/plans/2026-07-15-settings-system-appearance-transition.md`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppearancePreference.swift`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`

**Interfaces:**
- Consumes: `AppSettings.appearancePreference`, SwiftUI `preferredColorScheme`, `NSWindow.appearance`, and the user-supplied mixed-appearance screenshot.
- Produces: a recorded causal chain and transition matrix that later tasks must satisfy.

- [x] **Step 1: Reproduce the existing propagation failure**

The temporary AppKit hosting harness set the application host to Dark, rendered a root with `.preferredColorScheme(.light)`, changed the same modifier to `nil`, and recorded the inner `@Environment(\.colorScheme)`. Three consecutive runs produced:

```text
RED: SwiftUI content did not fully transition from Light to System Dark
initial: light
after System: light
sequence: dark -> light
```

This is red-capable for the reported symptom: the host is Dark but the live SwiftUI subtree remains Light after selecting System.

- [x] **Step 2: Falsify individual-color and persistence hypotheses**

The failure occurs in a minimal `Text` plus semantic `windowBackgroundColor` without `AppSettings`, Figma cards, sidebar code, or `UserDefaults`. Conditional removal of the preference modifier also remained Light. Therefore hard-coded surfaces, delayed persistence, and the three-column layout are not the root cause.

- [x] **Step 3: Confirm the scoped ownership alternative**

A second harness applied `.aqua` to one `NSWindow`, then cleared `window.appearance` while macOS was Dark. Three consecutive runs produced:

```text
GREEN: Settings-window Light transitioned to System Dark
initial: light
after System: dark
sequence: light -> dark
```

Application-wide ownership also transitioned correctly but is rejected because it would violate the native-menu system-appearance boundary.

- [ ] **Step 4: Record the implementation acceptance matrix before editing Swift**

Record expected effective appearance for Light → System under System Dark, Dark → System under System Light, both explicit round trips, macOS Light/Dark changes while System is selected, Settings reopen, and app relaunch. For each row, record Settings title bar, Navigation Sidebar, Settings Page, cards, controls, dividers, Context Rail, and native menu expectations.

---

### Task 2: Define the Settings-window appearance mapping and bridge

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppearancePreference.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowAppearanceBridge.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/SettingsWindowAppearanceBridgeTests.swift`

**Interfaces:**
- Consumes: `AppearancePreference` and the `NSWindow` containing Settings.
- Produces: `AppearancePreference.windowAppearance`, `SettingsWindowAppearanceController.apply(_:to:)`, and `SettingsWindowAppearanceBridge`.

- [ ] **Step 1: Write the failing window-transition tests**

Create main-actor XCTest coverage that temporarily sets `NSApplication.shared.appearance` to a known host appearance and restores it with `defer`. The key regression case must apply Light to one `NSWindow`, then apply System and assert both that the explicit window override is cleared and that `effectiveAppearance` inherits Dark:

```swift
@MainActor
final class SettingsWindowAppearanceBridgeTests: XCTestCase {
    func test_lightToSystemClearsOverrideAndInheritsDarkHost() {
        let application = NSApplication.shared
        let originalAppearance = application.appearance
        application.appearance = NSAppearance(named: .darkAqua)
        defer { application.appearance = originalAppearance }

        let window = NSWindow()
        SettingsWindowAppearanceController.apply(.light, to: window)
        XCTAssertEqual(window.appearance?.name, .aqua)

        SettingsWindowAppearanceController.apply(.system, to: window)
        XCTAssertNil(window.appearance)
        XCTAssertEqual(
            window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]),
            .darkAqua
        )
    }
}
```

Add the symmetric Dark → System/Light-host case and direct Light/Dark mapping cases.

- [ ] **Step 2: Run the focused test red**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter SettingsWindowAppearanceBridgeTests
```

Expected before implementation: compilation fails because `SettingsWindowAppearanceController` and `windowAppearance` do not exist.

- [ ] **Step 3: Replace the SwiftUI color-scheme mapping with an AppKit window mapping**

In `AppearancePreference.swift`, remove `colorScheme` and provide:

```swift
var windowAppearance: NSAppearance? {
    switch self {
    case .system: nil
    case .light: NSAppearance(named: .aqua)
    case .dark: NSAppearance(named: .darkAqua)
    }
}
```

Import AppKit instead of SwiftUI in that file.

- [ ] **Step 4: Implement one window-scoped owner**

Create an `NSViewRepresentable` whose anchor stores the latest preference, applies it when attached to a window, and reapplies it when the preference changes:

```swift
import AppKit
import SwiftUI

@MainActor
enum SettingsWindowAppearanceController {
    static func apply(_ preference: AppearancePreference, to window: NSWindow?) {
        window?.appearance = preference.windowAppearance
    }
}

struct SettingsWindowAppearanceBridge: NSViewRepresentable {
    let preference: AppearancePreference

    func makeNSView(context: Context) -> SettingsWindowAppearanceAnchor {
        SettingsWindowAppearanceAnchor(preference: preference)
    }

    func updateNSView(_ nsView: SettingsWindowAppearanceAnchor, context: Context) {
        nsView.preference = preference
    }
}

@MainActor
final class SettingsWindowAppearanceAnchor: NSView {
    var preference: AppearancePreference {
        didSet { applyAppearance() }
    }

    init(preference: AppearancePreference) {
        self.preference = preference
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
    }

    private func applyAppearance() {
        SettingsWindowAppearanceController.apply(preference, to: window)
    }
}
```

The anchor must not dispatch delayed competing writes or retain the window after detachment.

- [ ] **Step 5: Run the focused tests green**

Run the same filtered test command. Expected: all Settings-window appearance mapping and inheritance tests pass.

---

### Task 3: Install the bridge without rebuilding Settings state

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `settings.appearancePreference` and `SettingsWindowAppearanceBridge`.
- Produces: one live Settings window whose AppKit chrome and SwiftUI content share the same effective appearance.

- [ ] **Step 1: Attach the bridge to the existing root**

Remove:

```swift
.preferredColorScheme(settings.appearancePreference.colorScheme)
```

Attach the zero-layout bridge without changing the HStack identity:

```swift
.background {
    SettingsWindowAppearanceBridge(preference: settings.appearancePreference)
        .frame(width: 0, height: 0)
}
```

Do not add `.id(settings.appearancePreference)`, replace the Settings scene, or reset view-local state.

- [ ] **Step 2: Compile with warnings as errors**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors
```

Expected: `Build complete!` with no warning about actor isolation, unavailable initializers, or unused appearance ownership.

- [ ] **Step 3: Verify ownership by source inspection**

Run:

```bash
rg -n 'preferredColorScheme|NSApplication\.shared\.appearance|NSApp\.appearance|SettingsWindowAppearanceBridge' CodexUsageMonitor/Sources/CodexUsageMonitor
```

Expected: the Settings bridge is the only application code applying the preference; no app-wide appearance assignment exists, and `SettingsView` no longer uses `preferredColorScheme`.

---

### Task 4: Perform comprehensive signed-app visual acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-15-settings-system-appearance-transition.md`

**Interfaces:**
- Consumes: the signed app, Task 1 matrix, and the current 780 × 520 Settings shell.
- Produces: direct visual evidence for complete transitions and preserved interaction state.

- [ ] **Step 1: Build and launch only an audit-owned signed instance**

Run `zsh CodexUsageMonitor/Scripts/build-app.sh`, verify the bundle with `codesign --verify --deep --strict`, and open Settings through a normal app UI path. Track the audit PID and do not terminate any pre-existing user-owned process.

- [ ] **Step 2: Reproduce the original transition under System Dark**

Set Settings to Light, keep the window open, then choose System while macOS is Dark. Confirm in the same frame that title bar, sidebar, page background, section cards, controls, dividers, and Context Rail all become Dark without a mixed intermediate state persisting or requiring reopen.

- [ ] **Step 3: Exercise the symmetric and live-system transitions**

Under System Light, verify Dark → System becomes fully Light. With System selected and Settings open, change macOS between Light and Dark through the user's normal System Settings control and confirm the entire window follows each change. Restore the user's original macOS appearance afterward.

- [ ] **Step 4: Inspect every destination and preview state**

Open General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics in Light, Dark, and System. Repeat with the Context Rail visible and hidden. Check semantic card fills, title/description contrast, picker and toggle rendering, selection backgrounds, status badges, long text, clipping, and scrolling.

- [ ] **Step 5: Prove transition continuity**

Before changing appearance, enter a sidebar search, select a non-General destination, scroll its page, set the Context Rail state, and focus a control. Confirm those session states remain intact after every transition.

- [ ] **Step 6: Confirm the native-menu boundary**

With macOS Dark, force Settings Light and open the native menu. The Settings window should remain Light while the menu remains Dark/system-controlled. Repeat the inverse under macOS Light with Settings forced Dark.

- [ ] **Step 7: Verify reopen and relaunch behavior**

Confirm explicit Light/Dark persists across Settings reopen and app relaunch. Confirm System persists as System and follows the macOS appearance present at each reopen/relaunch rather than persisting a resolved Light/Dark snapshot.

---

### Task 5: Reconcile documentation and verification evidence

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-global-sidebar.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`

**Interfaces:**
- Consumes: accepted implementation behavior and Task 4 signed-app evidence.
- Produces: accurate current behavior, regression history, and any remaining visual limitations.

- [ ] **Step 1: Replace the known-limitation language only after acceptance**

Record the Settings-window ownership model, all directly observed transitions, appearances, destinations, preview states, persistence results, and native-menu boundary. Do not claim a System-Light or System-Dark path that was not actually inspected.

- [ ] **Step 2: Run final integrity checks**

Run `git diff --check`, the focused test, warnings-as-errors build, signed-app build, and strict codesign verification. Record exact outputs and any manual limitations in this plan before committing.

## Self-review

- Root cause: the plan fixes the stale presentation-level preference rather than recoloring individual Figma surfaces.
- Scope: only the Settings `NSWindow` receives an override; native menu presentation remains system-controlled.
- State continuity: no view identity or window recreation workaround is allowed.
- Visual coverage: the original transition, its symmetric case, live macOS changes, all six destinations, both Context Rail states, persistence, and menu-boundary behavior are explicit acceptance gates.
- Evidence quality: the red/green harness proves the ownership boundary, while only the signed app can close visual acceptance.
