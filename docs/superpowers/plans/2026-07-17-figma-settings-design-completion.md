# Figma Settings Design Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** **In progress — Tasks 1–5 are implemented; Task 6 remains planned.** Signed-app visual acceptance remains pending. This plan does not revive or merge `feature/figma-settings-port`.

**Goal:** Complete the remaining approved Figma-inspired Settings behavior while preserving the current native global-sidebar theme, semantic colors, live System/Light/Dark presentation, controls, settings values, and all existing app behavior.

**Architecture:** `SettingsView` remains the single owner of the global navigation selection, Context Rail visibility, and concrete Settings presentation color scheme. A small value-type layout model fixes the Navigation Sidebar and Settings Page widths while the window adds or removes only the Context Rail allocation. `SettingsPreferenceToggle` standardizes real Boolean preferences on the native macOS switch; it does not create preferences or reinterpret non-Boolean controls. The General page loses its duplicate menu preview while `GeneralSettingsContextView` becomes the single full-width preview owner. `GeneralSettingsView` presents the existing Settings appearance preference as a bounded native three-option segmented picker under Menu Bar Icon; Diagnostics owns existing Application metadata.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit window geometry only, existing Combine-backed `AppSettings`, XCTest for one deterministic layout invariant, and the signed macOS app build script.

## Source and scope boundary

The historical imported design at `feature/figma-settings-port:High-fidelity macOS menu UI/src/components/PreferencesWindow.tsx` is a structural reference only. It is not a runtime dependency, asset source, or implementation branch. Before visual implementation, obtain either a current Figma Design URL/node or a fresh Figma Desktop selection and capture its screenshot; record any material visual difference from the historical artifact in this plan before coding.

This plan implements only current, supported native behavior:

| Historical/reference element | Native completion decision |
| --- | --- |
| Global destination sidebar, page header, contextual rail | Preserve the existing native implementation and current semantic theme. |
| Right rail hidden/visible geometry | Add the documented fixed-left-region, window-local transition. |
| Launch, keyboard, notification, threshold, and warning Boolean controls | Use one shared native switch presentation. |
| Appearance and menu-bar style/value choices | Keep native pickers: they are multi-value choices, not switches. |
| General menu-bar preview | Keep one larger full-width Context Rail preview; remove the duplicate page preview and Current Scope. |
| Menu Bar Icon Appearance | Use the reference's System/Light/Dark horizontal selector as a native bounded `.segmented` picker for the existing Settings appearance preference. The native menu remains macOS-controlled. |
| Application version metadata | Move the existing Name, Version, and Build rows from General to Diagnostics; do not add the reference's unsupported Swift, Codex-version, architecture, export, or log-copy fields. |
| Figma-only Show in Menu Bar, Start Minimized, Open on Update, refresh-on-open/wake, notification summaries, credit-expiry preferences, cache reset, export, and generated provider controls | Do not port: no backed behavior, approved persistence, or product requirement exists. |

### v4 reference confirmation — 2026-07-18

The user-provided local `High-fidelity macOS menu UI v4/src/components/PreferencesWindow.tsx` is the structural, non-runtime reference for this slice. Its General **Menu Bar Icon** group contains an **Appearance** `SegmentedControl` with exactly **System**, **Light**, and **Dark** (lines 554–574), and its Diagnostics **Developer Information** group contains an app-version row (lines 723–756). No Figma MCP URL or Desktop selection is available, so no Figma screenshot is claimed; no React/CSS code or asset will be imported. The native app uses semantic SwiftUI controls and requires signed-app manual acceptance.

## Global constraints

- Start from current `origin/main`; do not cherry-pick, merge, or rebase the historical Figma branch.
- Preserve the current global `SettingsNavigationSidebar`, `SettingsDetailView`, `SettingsPreviewView`, all six destinations, existing selected-destination persistence, and current visual theme. Do not reintroduce a top-level `Form`, lower destination sidebar, web runtime, generated React/CSS assets, bitmap mockup, or a second Settings navigation owner.
- Resolve the stale top-`TabView` sentence in `AGENTS.md` before source changes. The accepted current shell uses the global sidebar; the guardrail must instead protect that shell and the fixed left-region geometry.
- Preserve `SettingsView` as the one appearance-presentation owner. It must continue using `SystemAppearanceObserver` and a concrete `preferredColorScheme`; never set `NSApplication.appearance` or `NSWindow.appearance`.
- The default Settings content size is 680 × 560 points when the Context Rail is hidden. The visible rail adds exactly `SettingsLayoutMetrics.contextRailWidth + SettingsLayoutMetrics.dividerWidth` to the right edge; the Navigation Sidebar and Settings Page retain their hidden-state frames.
- Context Rail visibility starts hidden for each Settings-window lifetime, is not persisted, and does not change the selected destination, search query, scroll position, preview data, focus, or any `AppSettings` value.
- Use `SettingsPage`, `SettingsSection`, `SettingsLabeledRow`, `SettingsDescription`, and centralized `SettingsLayoutMetrics`. Keep pages scrollable and controls bounded.
- Use `SettingsPreferenceToggle` for every current independent Boolean preference. It must wrap a native `Toggle` using `.toggleStyle(.switch)` and semantic system styles. Checkboxes are reserved for future batch selection; no current preference needs one.
- Keep pickers, buttons, permission recovery, status labels, Refresh Now, and future two-choice policies as their current native control types. Do not represent multi-value or destructive actions as switches.
- The General **Menu Bar Icon** group owns the Settings-window **Appearance** segmented picker. Its choices are **System**, **Light**, and **Dark** and bind only to the existing `AppSettings.appearancePreference`; it must not set `NSApplication.appearance`, `NSWindow.appearance`, or alter native menu appearance.
- Add one focused layout regression test only. Native layout, rail resizing, appearance, VoiceOver, and conditional-state verification require the signed app and direct inspection; do not add a generic UI-test suite.
- Do not implement indexed exact-control search, provider warning scopes, provider controls, Permissions, or additional Figma surfaces here. Their separate plans remain deferred.

---

## File structure

- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowLayout.swift`: pure, testable hidden/visible width calculation; no AppKit or persistence ownership.
- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowWidthAnchor.swift`: AppKit content-size coordinator that changes only the Settings window's geometry and keeps its left edge fixed.
- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceToggle.swift`: reusable native switch row for current Boolean preferences.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`: own the hidden/visible window metrics, divider width, and fixed Settings Page width.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`: start with rail hidden, use `SettingsWindowLayout`, and attach the geometry-only anchor without changing appearance ownership.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`: retain the existing trailing rail control with explicit visible/hidden accessibility labels.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift` and `GeneralSettingsContextView.swift`: remove duplicate/obsolete General information and make the rail preview authoritative.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`: replace all existing Boolean rows with the shared switch component while preserving authorization and disabled hierarchy.
- Modify `CodexUsageMonitor/Tests/CodexUsageMonitorTests/SettingsWindowLayoutTests.swift`: one focused geometry-invariant regression test.
- Modify `AGENTS.md`, `docs/product/follow-ups.md`, `docs/product/planning-board.md`, this plan, `docs/superpowers/plans/2026-07-14-settings-provider-followups.md`, `how-to.md`, `UsageProbe/README.md`, and `outline.md`: reconcile the current shell contract, source status, operating behavior, and acceptance evidence after implementation.

## Task 1: Reconcile the current Settings shell contract and make geometry deterministic — complete

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowLayout.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/SettingsWindowLayoutTests.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes centralized layout metrics and `Bool isContextRailVisible`.
- Produces `SettingsWindowLayout` with stable sidebar/page dimensions and a content size that differs only by the rail allocation.

- [x] **Step 1: Correct the repository navigation guardrail before changing Settings source.**

Replace the obsolete instruction that requires a top `TabView` with this exact current-shell constraint:

```markdown
- Keep `SettingsView` as the owner of the global `SettingsNavigationSidebar`, selected destination, `SettingsDetailView`, and Context Rail visibility. The sidebar and Settings Page frames must remain stable when the rail is hidden or shown; provider navigation belongs inside the Agents destination and must not create a second window-level navigation owner.
```

Keep all existing Form/LabeledContent, scrollability, semantic-color, and signed-app requirements unchanged.

- [x] **Step 2: Add the focused failing geometry regression.**

```swift
import XCTest
@testable import CodexUsageMonitor

final class SettingsWindowLayoutTests: XCTestCase {
    func test_contextRailOnlyChangesTheRightHandWindowAllocation() {
        let hidden = SettingsWindowLayout(isContextRailVisible: false)
        let visible = SettingsWindowLayout(isContextRailVisible: true)

        XCTAssertEqual(hidden.sidebarWidth, visible.sidebarWidth)
        XCTAssertEqual(hidden.settingsPageWidth, visible.settingsPageWidth)
        XCTAssertEqual(hidden.contentSize.height, visible.contentSize.height)
        XCTAssertEqual(
            hidden.contentSize,
            CGSize(
                width: SettingsLayoutMetrics.hiddenWindowWidth,
                height: SettingsLayoutMetrics.targetWindowHeight
            )
        )
        XCTAssertEqual(
            visible.contentSize,
            CGSize(
                width: SettingsLayoutMetrics.hiddenWindowWidth
                    + SettingsLayoutMetrics.contextRailWidth
                    + SettingsLayoutMetrics.dividerWidth,
                height: SettingsLayoutMetrics.targetWindowHeight
            )
        )
        XCTAssertEqual(
            visible.contentSize.width - hidden.contentSize.width,
            SettingsLayoutMetrics.contextRailWidth + SettingsLayoutMetrics.dividerWidth
        )
    }
}
```

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter SettingsWindowLayoutTests/test_contextRailOnlyChangesTheRightHandWindowAllocation
```

Initial RED evidence showed the original missing `SettingsWindowLayout`, `contextRailWidth`, and `dividerWidth` symbols. The review follow-up added the exact 680 × 560 target assertions first; its focused test failed as intended because `targetWindowHeight` did not yet exist.

- [x] **Step 3: Add metrics and the pure layout model.**

Keep all numbers in `SettingsLayoutMetrics`:

```swift
static let hiddenWindowWidth: CGFloat = 680
static let targetWindowHeight: CGFloat = 560
static let sidebarWidth: CGFloat = 180
static let contextRailWidth: CGFloat = 210
static let dividerWidth: CGFloat = 1
static let settingsPageWidth = hiddenWindowWidth - sidebarWidth - dividerWidth
```

Create:

```swift
import CoreGraphics

struct SettingsWindowLayout: Equatable {
    let contentSize: CGSize
    let sidebarWidth: CGFloat
    let settingsPageWidth: CGFloat

    init(isContextRailVisible: Bool) {
        sidebarWidth = SettingsLayoutMetrics.sidebarWidth
        settingsPageWidth = SettingsLayoutMetrics.settingsPageWidth
        let railAllocation = isContextRailVisible
            ? SettingsLayoutMetrics.contextRailWidth + SettingsLayoutMetrics.dividerWidth
            : 0
        contentSize = CGSize(
            width: SettingsLayoutMetrics.hiddenWindowWidth + railAllocation,
            height: SettingsLayoutMetrics.targetWindowHeight
        )
    }
}
```

`SettingsWindowLayout` owns the Task 2 target contract (680 × 560 hidden, 891 × 560 visible). During Task 1, `SettingsView` retains its pre-existing frame; Task 2 applies the model to live geometry. Do not duplicate the arithmetic in a view.

- [x] **Step 4: Run the focused test green and commit the contract/layout slice.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter SettingsWindowLayoutTests/test_contextRailOnlyChangesTheRightHandWindowAllocation
git add AGENTS.md CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowLayout.swift CodexUsageMonitor/Tests/CodexUsageMonitorTests/SettingsWindowLayoutTests.swift
git commit -m "Stabilize Settings rail geometry"
```

Expected: 1 test passes with 0 failures. The test proves the structural width invariant and exact target dimensions, not real-window behavior.

### Task 1 completion evidence and boundary

- The initial contract/layout slice is commit `a8204e3 Stabilize Settings rail geometry`.
- The reviewer follow-up kept the live Settings frame unchanged during Task 1 and introduced the separate `targetWindowHeight` of 560. `SettingsWindowLayout` uses only the target height; after Task 2 applied that model, the now-unused legacy 780 × 520 metrics were removed in `f5b3b38`.
- The focused XCTest was run RED after the target assertions were added and failed only for the missing `targetWindowHeight` metric. The focused test and full package suite were then run after the correction; their command output and final follow-up commit are recorded in `.superpowers/sdd/task-1-report.md`.
- No Task 2 source was started in this correction: `SettingsView` does not consume `SettingsWindowLayout`, the Context Rail frame is unchanged, and no signed app was built or visually inspected. Task 2 owns the live 680 × 560 hidden-size application, the 211-point visible-rail expansion, and all signed-app geometry acceptance.

## Task 2: Make the Context Rail a window-local, fixed-geometry transition

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowWidthAnchor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsContextPanel.swift`

**Interfaces:**
- Consumes `SettingsWindowLayout.contentSize` and the existing `isPreviewVisible` window-local `@State`.
- Produces a left-edge-preserving content-size update, a fixed-width Settings Page, and an accessible Show/Hide Context Rail button.

- [x] **Step 1: Add the geometry-only AppKit anchor.**

```swift
import AppKit
import SwiftUI

struct SettingsWindowWidthAnchor: NSViewRepresentable {
    let contentSize: CGSize

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onWindowAvailable = { window in
            context.coordinator.apply(contentSize, to: window)
        }
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        if let window = view.window {
            context.coordinator.apply(contentSize, to: window)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class AnchorView: NSView {
        var onWindowAvailable: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindowAvailable?(window) }
        }
    }

    final class Coordinator {
        private var lastContentSize: CGSize?

        func apply(_ contentSize: CGSize, to window: NSWindow) {
            guard lastContentSize != contentSize else { return }
            let leftEdge = window.frame.minX
            window.setContentSize(contentSize)
            window.setFrameOrigin(NSPoint(x: leftEdge, y: window.frame.minY))
            lastContentSize = contentSize
        }
    }
}
```

This component must never write `appearance`, create a window, delay a write, or own Settings state.

- [x] **Step 2: Apply the layout once in `SettingsView`.**

Start from hidden rail state and keep the page fixed:

```swift
@State private var isPreviewVisible = false

var body: some View {
    let layout = SettingsWindowLayout(isContextRailVisible: isPreviewVisible)

    HStack(spacing: 0) {
        SettingsNavigationSidebar(selection: $settings.selectedSettingsTab)
        Divider()
        settingsPage
            .frame(width: layout.settingsPageWidth, height: layout.contentSize.height)
        if isPreviewVisible {
            Divider()
            SettingsContextPanel {
                SettingsPreviewView(
                    selection: settings.selectedSettingsTab,
                    viewModel: viewModel
                )
            }
        }
    }
    .frame(width: layout.contentSize.width, height: layout.contentSize.height)
    .background(SettingsWindowWidthAnchor(contentSize: layout.contentSize))
    .preferredColorScheme(
        settings.appearancePreference.presentationColorScheme(
            system: systemAppearance.colorScheme
        )
    )
}
```

Extract the existing middle `VStack` into this exact `settingsPage` property; do not change its selected destination, view model, or appearance owner:

```swift
private var settingsPage: some View {
    VStack(spacing: 0) {
        SettingsPageHeader(
            title: settings.selectedSettingsTab.title,
            isPreviewVisible: $isPreviewVisible
        )
        Divider()
        SettingsDetailView(
            selection: settings.selectedSettingsTab,
            viewModel: viewModel,
            launchAtLogin: launchAtLogin
        )
    }
}
```

Keep the existing Reduce Motion value-based rail transition. `SettingsContextPanel` retains `contextRailWidth`; do not let it request unbounded width.

- [x] **Step 3: Make the rail action understandable without color or icon-only ambiguity.**

Retain the trailing native button and add an explicit VoiceOver label/value:

```swift
Button(
    isPreviewVisible ? "Hide Context Rail" : "Show Context Rail",
    systemImage: "sidebar.right",
    action: togglePreview
)
.labelStyle(.iconOnly)
.accessibilityLabel(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
.accessibilityValue(isPreviewVisible ? "Visible" : "Hidden")
.help(isPreviewVisible ? "Hide Context Rail" : "Show Context Rail")
```

- [ ] **Step 4: Build the signed app and inspect geometry before proceeding.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
```

Open only an audit-owned signed app instance. At default size, toggle the rail for every destination and verify: hidden starts at 680 × 560; visible adds 211 points at the right edge; left edge, sidebar, page, selection, search text, scroll, and focus do not move; rail content never covers a control. Repeat under Light, Dark, and System without changing `NSApplication.appearance`.

### Task 2 implementation evidence and outstanding visual acceptance

- `SettingsWindowWidthAnchor` applies only the target content size to its containing window and restores the prior left edge. Its coordinator is main-actor isolated and deduplicates unchanged sizes; it does not own Settings state or write appearance.
- `SettingsView` now starts with the rail hidden, consumes `SettingsWindowLayout`, fixes the Settings Page to the layout width/height, and retains its existing `SystemAppearanceObserver` and concrete `preferredColorScheme` ownership. Showing the rail adds only the layout model's 211-point right-side allocation.
- The header's icon presentation now has explicit Show/Hide Context Rail VoiceOver label, state value, and help text. `SettingsContextPanel` uses the centralized rail width directly.
- The focused `SettingsWindowLayoutTests/test_contextRailOnlyChangesTheRightHandWindowAllocation` and full Swift package suite passed after the Task 2 source change (8 tests, 0 failures). The signed app built successfully; `codesign --verify --deep --strict --verbose=2` and `plutil -lint` passed.
- **Not run:** direct signed-app window inspection and the Light/Dark/System, six-destination interaction matrix. This session could not safely identify an audit-owned app instance (`pgrep` process enumeration was unavailable), so it did not launch or interfere with a potentially user-owned monitor. Task 4 retains this mandatory manual acceptance gate.

## Task 3: Complete the approved General rail and native preference switches — complete

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceToggle.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsContextView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`

**Interfaces:**
- Produces `SettingsPreferenceToggle(title:description:isOn:)` for current Boolean bindings and exactly one General menu-bar preview in the Context Rail.
- Consumes the existing bindings and callbacks unchanged; no new persistence key, notification category, permission, or menu behavior is introduced.

- [x] **Step 1: Add the shared native preference switch.**

```swift
import SwiftUI

struct SettingsPreferenceToggle: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool

    init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayoutMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let description {
                    SettingsDescription(description)
                }
            }
            Spacer(minLength: SettingsLayoutMetrics.rowSpacing)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Do not add custom checkbox graphics, custom colors, or a new storage owner. The surrounding section's `.disabled(...)` must continue disabling both the label and switch.

- [x] **Step 2: Replace only existing Boolean preference rows.**

Use the component for Launch at Login, Enable keyboard shortcuts, Enable quota notifications, all `RemainingQuotaThreshold` rows, Forecasted exhaustion, Reset-credit expiration, Quota reset or reset failure, Stale quota data, and Extended update interruptions. Keep the existing `setAlertsEnabled`, threshold bindings, authorization message, permission button, disabled hierarchy, pickers, and Refresh Now action unchanged.

```swift
SettingsPreferenceToggle(
    "Enable quota notifications",
    description: "Allow quota alerts after macOS notification permission is granted.",
    isOn: Binding(
        get: { settings.alertsEnabled },
        set: setAlertsEnabled
    )
)
```

Use the existing product copy for other settings where no new description is needed. Do not port unsupported reference-only Boolean controls.

- [x] **Step 3: Make General's Context Rail preview the one authoritative preview.**

Remove `SettingsLabeledRow("Preview")` from General's Menu Bar section and remove the entire `Current Scope` section. Replace the `Current label` HStack in `GeneralSettingsContextView` with one full-width preview:

```swift
SettingsContextCard("Menu Bar Preview") {
    MenuBarLabelView(
        presentation: MenuBarLabelPresentation(
            displayState: displayState,
            style: settings.menuBarDisplayStyle,
            valueMode: settings.quotaValueMode
        )
    )
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.vertical, 14)
    .background(.quaternary, in: .rect(cornerRadius: 8))
}
```

Keep Current Usage and Collection cards only when they are based on existing live state. Do not add mock account data, credit-expiry cards, or Figma-generated status values.

- [x] **Step 4: Verify native controls and commit this visual slice.**

In the signed app inspect the default window and both rail states: every converted control displays a native switch; the notification master correctly disables all child switches; denied permission still exposes recovery guidance; Launch at Login guidance still wraps; General has one preview and no Current Scope; keyboard and VoiceOver can reach the rail control and each switch. Check Light, Dark, and System with the existing appearance matrix.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceToggle.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsContextView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift
git commit -m "Complete native Settings control styling"
```

Expected: the focused layout regression and full test suite pass. Record any unmanufactured permission or connection state as **Not run**.

### Task 3 completion evidence and boundary

- `SettingsPreferenceToggle` now renders every current independent Boolean preference in General and Notifications as an accessibility-labelled native `.switch`, while retaining all existing bindings, disabled hierarchy, authorization guidance, permission recovery, pickers, and actions.
- General's duplicate page preview and obsolete Current Scope section are removed. The Context Rail owns one full-width Menu Bar Preview; its Current Usage and Collection cards still derive only from existing live state.
- The focused geometry regression and full package suite passed after the Task 3 change (8 tests, 0 failures). The signed app built successfully; `codesign --verify --deep --strict --verbose=2`, `plutil -lint`, and `git diff --check` passed.
- **Not run:** direct signed-app visual acceptance of native switches, the denied-permission state, launch-at-login wrapping, VoiceOver/keyboard traversal, both rail states, and the Light/Dark/System appearance matrix. This task did not launch or interfere with a potentially user-owned monitor; Task 4 retains the mandatory manual acceptance gate.

## Task 4: Complete signed-app acceptance and synchronize planning sources

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-figma-settings-design-completion.md`
- Modify: `docs/superpowers/plans/2026-07-14-settings-provider-followups.md`
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-global-sidebar.md`
- Modify: `docs/superpowers/plans/2026-07-15-settings-system-appearance-transition.md`
- Modify: `docs/product/follow-ups.md`
- Modify: `docs/product/planning-board.md`
- Modify: `how-to.md`, `UsageProbe/README.md`, and `outline.md`

- [x] **Step 1: Run final static checks.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
git diff --check
```

- [ ] **Step 2: Perform the complete real-window matrix.**

For all six destinations, inspect Context Rail hidden then visible at the default window sizes. Exercise General's removed/authoritative preview path, enabled and disabled notification controls, denied notification recovery, missing connection guidance, unavailable quota values, long status text, scrollbar reachability, keyboard navigation, VoiceOver labels, and repeated open/close cycles. Run the existing System/Light/Dark transition matrix in the same live window and confirm the native menu stays system-controlled.

Do not manufacture quota consumption, edit user credentials, or close a user-owned monitor process. If an isolated state cannot safely be created, list it as **Not run** in the plan and PR draft.

- [x] **Step 3: Reconcile sources without claiming unsupported Figma behavior.**

Mark Product Follow-up 5 and the planning-board design-completion rows **Verification** only after the acceptance matrix is observed. Update the provider follow-up plan to state that its UI-only Task 1 geometry/switch subset was implemented here; keep search and provider lifecycle tasks deferred. Keep Other Figma Surfaces deferred. Document the actual rail behavior and all remaining limitations in operating guides.

- [x] **Step 4: Prepare the manual PR handoff.**

Create `.worktrees/figma-settings-design-completion-PR.md` from `.github/pull_request_template.md`. Include only observed evidence, the focused layout regression result, signed-app result, visual matrix outcome, limitations, rollback, and the fact that the user manually creates every GitHub PR. Do not invoke PR creation.

## Task 5: Group Appearance under Menu Bar Icon and move Application metadata to Diagnostics

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift`

**Interfaces:**
- Consumes the existing `AppSettings.appearancePreference`, `MenuBarDisplayStyle`, `QuotaValueMode`, and `SettingsStatus` values.
- Produces only a native presentation/layout reorganization; it creates no preference key, status field, appearance owner, or menu behavior.

- [x] **Step 1: Add the bounded segmented-control metric.**

In `SettingsLayoutMetrics`, add one shared value next to the existing control metric:

```swift
static let appearanceSegmentedControlWidth: CGFloat = 240
```

Do not add view-local width or padding constants. The bounded 240-point control fits the fixed Settings Page value column while allowing the three System/Light/Dark segments to remain distinct.

- [x] **Step 2: Reorganize General without changing the persisted preference or appearance owner.**

Remove the standalone `SettingsSection("Appearance")` entirely. Rename the current `SettingsSection("Menu Bar")` to `SettingsSection("Menu Bar Icon")`, and rename its current `MenuBarDisplayStyle` row from **Appearance** to **Style** so it does not conflict with the app presentation preference.

After the existing **Show** row, add the native three-option horizontal selector:

```swift
SettingsLabeledRow("Appearance") {
    Picker("Appearance", selection: $settings.appearancePreference) {
        ForEach(AppearancePreference.allCases) { appearance in
            Text(appearance.title).tag(appearance)
        }
    }
    .labelsHidden()
    .pickerStyle(.segmented)
    .frame(width: SettingsLayoutMetrics.appearanceSegmentedControlWidth)
    .accessibilityLabel("Appearance")
}

SettingsDescription("Controls the Settings window appearance. The menu bar follows macOS.")
    .settingsValueColumnAligned()
```

This is a native SwiftUI adaptation of the v4 reference's horizontal System/Light/Dark selector, not a port of its React `SegmentedControl`. Keep `SettingsView` as the sole resolver of the concrete `preferredColorScheme` through `SystemAppearanceObserver`; do not write `NSApplication.appearance` or `NSWindow.appearance`. Keep the existing menu-bar **Style** and **Show** pickers and their semantics unchanged.

- [x] **Step 3: Move the existing Application section to Diagnostics.**

Remove this block from the end of `GeneralSettingsView`:

```swift
SettingsSection("Application") {
    SettingsLabeledRow("Name") { Text("Codex Usage Monitor") }
    SettingsLabeledRow("Version") { Text(status.appVersion) }
    SettingsLabeledRow("Build") { Text(status.buildNumber) }
}
```

Append the exact same block at the end of `DiagnosticsSettingsView`'s `SettingsPage`. Keep the existing `status` input unchanged and do not add the reference's unsupported developer-information rows, export action, or log-copy action.

- [x] **Step 4: Run the allowed regression checks and record the manual native boundary.**

No additional automated UI test is added: this is native Settings presentation/reorganization, and the repository intentionally permits only the existing focused geometry regression rather than a generic UI-test suite. The existing appearance-presentation tests continue to protect the System/Light/Dark value semantics; direct native segmented-control presentation and live transition behavior require the signed app.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter SettingsAppearancePresentationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
git diff --check
```

In an audit-owned signed app, inspect General with both Context Rail states and verify **Menu Bar Icon** contains **Style**, **Show**, and a horizontal **Appearance** control with System, Light, and Dark. Verify selection changes the Settings presentation without changing native menu appearance, retains destination/search/scroll/rail/focus state, and remains usable in Light and Dark. Inspect Diagnostics to verify Name, Version, and Build are present exactly once and absent from General. If no audit-owned instance can be safely launched, record every visual result as **Not run** and leave the Draft/manual acceptance gate open.

- [x] **Step 5: Commit the native organization slice.**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift docs/superpowers/plans/2026-07-17-figma-settings-design-completion.md
git commit -m "Organize Settings appearance and diagnostics"
```

### Task 5 completion evidence and remaining gate

- **Run (2026-07-18):** the existing `SettingsAppearancePresentationTests` filter, full package suite, signed app build, strict `codesign` verification, `plutil -lint`, and `git diff --check` passed; command outputs are recorded in `.superpowers/sdd/task-5-report.md`.
- **Not run:** no audit-owned signed app could be safely launched during this implementation task. Direct inspection of the General segmented control in both Context Rail states, Diagnostics metadata placement, live appearance transitions and session-state retention, native-menu independence, and Light/Dark usability remains the manual acceptance gate.

## Task 6: Synchronize post-Task-5 evidence without advancing manual acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-figma-settings-design-completion.md`
- Modify: `docs/product/follow-ups.md`
- Modify: `docs/product/planning-board.md`
- Modify: `how-to.md`, `UsageProbe/README.md`, and `outline.md`
- Modify (ignored handoff): `.worktrees/figma-settings-design-completion-PR.md`

- [ ] **Step 1: Re-run final static checks and preserve the signed-app distinction.**

Run the full package suite, signed build, strict code-signature validation, plist lint, and `git diff --check`. Record exact results as **Run**. Record the General segmented-control, Diagnostics relocation, live appearance transition, and native-menu checks as **Observed** only after direct signed-app inspection; otherwise retain **Not run**.

- [ ] **Step 2: Update operating and planning wording.**

Describe General's **Menu Bar Icon** group as containing **Style**, **Show**, and the Settings-window **Appearance** segmented control. State that the native menu remains system-controlled. Describe Diagnostics as the owner of Name, Version, and Build. Keep Product Follow-up 5 and related board rows **Queued** until the full signed-app matrix, including this new control, is observed. Update the ignored Draft PR handoff with the actual commit and evidence; never push or create a GitHub PR.

## Task 5 acceptance criteria

- General has no standalone Appearance section and no Application metadata section.
- General's **Menu Bar Icon** section contains a native bounded System/Light/Dark horizontal **Appearance** picker plus the existing unchanged **Style** and **Show** pickers.
- Selecting an appearance writes only the existing `general.appearance` preference and keeps `SettingsView`/`SystemAppearanceObserver` as the presentation owner; the native menu remains macOS-controlled.
- Diagnostics contains Name, Version, and Build exactly once; no unsupported reference-only developer/diagnostic controls are introduced.
- The existing focused geometry regression and appearance-presentation suite still pass; signed-app visual results are documented as Observed or Not run without inference.

## Acceptance criteria

- The current global-sidebar Settings theme and all six destinations remain intact; the stale branch is never merged.
- The Context Rail is hidden on every new Settings window, opens from the stable page-header control, and changes only the right-side allocation while preserving left-region geometry and session state.
- Every current independent Boolean preference uses one accessible native switch; checkboxes and Figma-only fake controls are not introduced.
- General has exactly one full-width live menu-bar preview in the Context Rail, no Current Label text, no page-level duplicate Preview, and no Current Scope section.
- Existing appearance ownership stays intact through System/Light/Dark changes, and native menu appearance remains independent.
- One focused geometry regression protects the nonvisual invariant; signed-app inspection records all visual/interaction evidence and explicit unrun states.

## Deferred work deliberately excluded

- Indexed search and exact-control routing: `2026-07-14-settings-provider-followups.md` Task 2.
- Provider/window warning scope, notification identity, Disconnect, agent selector, and menu-bar-agent policy: Tasks 3–7 of the same plan, pending actual provider capability.
- Dedicated Permissions destination and richer refresh explanation: Product Follow-ups 6 and 7, each still requiring a dedicated plan.
- Dashboard, menu popover, widget, Watch, and other Figma surfaces: remain deferred until separately directed with approved current nodes.

### Task 4 completion evidence and remaining gate

- **Run (2026-07-18):** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor` passed: 8 tests, 0 failures, including `SettingsWindowLayoutTests/test_contextRailOnlyChangesTheRightHandWindowAllocation`.
- **Run (2026-07-18):** the signed app build, strict `codesign` verification, `plutil -lint`, and `git diff --check` passed. These prove the package, bundle, signature, plist, and diff hygiene; they do not prove native Settings presentation or interaction.
- **Not run:** the complete real-window matrix. No audit-owned monitor instance could be safely identified in this session, so no Settings app was launched, closed, or inspected. The six-destination hidden/visible Context Rail pass; General preview cleanup; notification, connection, quota, and long-status conditional states; scrollbar, keyboard, VoiceOver, and open/close cycles; the live System/Light/Dark transition matrix; and the native-menu appearance boundary all remain manual acceptance work.
- Product Follow-up 5 and the related planning-board rows remain **Queued**, rather than advancing to Verification or Closed, until that signed-app matrix is directly observed. The local `High-fidelity macOS menu UI v4` artifact informed structure only; it is not a runtime dependency, source import, or asset input, and React/CSS/assets remain excluded.
