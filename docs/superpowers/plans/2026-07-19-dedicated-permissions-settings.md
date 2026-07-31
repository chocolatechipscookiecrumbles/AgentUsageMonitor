# Dedicated Permissions Settings and Accepted Figma Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** **Deferred by user direction — 2026-07-19.** The app has only contextual notification, Login Items, and Terminal Automation surfaces; Accessibility is not required. Keep permission request/recovery beside the feature that needs it. Do not start a separate Permissions destination or Figma port unless the app later gains several required permissions or direct user evidence shows that the contextual recovery flow is insufficient.

**Goal:** Add a native macOS **Permissions** Settings destination that centralizes notification authorization and Login Items status/actions, accurately reports Accessibility access without requesting an unneeded permission, and implements only an explicitly accepted Figma-to-native adaptation.

**Architecture:** `SettingsView` stays the sole owner of Settings navigation, appearance, and Context Rail visibility. `QuotaMonitor`/`QuotaNotifier` stay the sole notification authorization/request owners; `LaunchAtLoginController` stays the sole Login Items owner. A small read-only Accessibility controller can check current trust and open its native pane only after a user click. The page uses existing Settings cards and rows—no second permission store, polling loop, custom window, or menu work.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, `UserNotifications`, `ServiceManagement`, `ApplicationServices`, existing Settings components, and Figma MCP once the user provides a concrete node.

## Source facts and scope boundary

- `SettingsTab`, `SettingsNavigationSidebar`, `SettingsDetailView`, and `SettingsPreviewView` route the six current top-level destinations.
- `NotificationAuthorizationState` is already published through `AppSettings`; only `QuotaNotifier` requests macOS authorization through `QuotaMonitor.setAlertsEnabled(_:)`. `QuotaViewModel.openNotificationSettings()` already opens the system pane.
- `LaunchAtLoginController` is the only owner of `SMAppService.mainApp`, registration, status, and Login Items navigation.
- The app currently has no Accessibility-dependent feature. It may show `AXIsProcessTrusted()` as system state, but must label that access **not required by the current app**, never request it, and never gate monitoring, login, menu, or refresh behavior on it.
- Automation, Screen Recording, Full Disk Access, Input Monitoring, Contacts, Calendar, and Files and Folders are excluded: the app does not use them. Do not add speculative links or prompts.
- Figma MCP requires a `/design/` or `/file/` node (or Desktop selection), metadata, design context, screenshot, variables, asset inventory, and explicit user acceptance before a Figma port can be claimed.

## Deferral decision — 2026-07-19

The proposed page would duplicate current controls more than it would reduce user effort:

- Notifications already requests and repairs authorization in Notifications Settings.
- Login Items already exposes its working control and native recovery action in General.
- Terminal Automation is requested only after the user explicitly chooses CLI sign-in.
- Accessibility is not required by any current app behavior and should not be promoted as a prerequisite.

Resume this plan only after a feature genuinely requires additional macOS access, or after repeated user evidence shows that the contextual controls fail to explain/recover a denied state. If resumed, begin at Task 1; no production task in this plan has started.

## Global constraints

- No visual implementation begins until Task 1 records a concrete Figma source and the user accepts the native adaptation audit.
- Preserve the existing global sidebar, selected destination, search, Context Rail width/visibility, System/Light/Dark ownership, semantic colors, and native controls. Do not add `Form`, `LabeledContent`, `.id(selectedSettingsTab)`, page-local layout constants, transparent spacers, or a second navigation owner.
- Use `SettingsPage`, `SettingsSection`, `SettingsSectionRow`, `SettingsPreferenceControlRow`, `SettingsDescription`, and `SettingsLayoutMetrics`. Descriptions must be callout-sized, wrap vertically, and remain reachable at the default 680 × 560-point hidden-rail size.
- Refresh permission state only on page appearance, after an explicit permission action, and through existing app startup. Do not add a timer, polling task, menu callback, or automatic permission request.
- Do not read credentials, account identity, raw provider output, or private quota data. Do not add a dependency, new persisted schema, network request, or permission request caused by merely opening Settings.
- Do not add broad automated tests or general test cases by user direction. Run the existing Swift package suite as regression baseline; add a narrow deterministic regression test later only for a reproducible controller defect.
- Update the product follow-up, planning board, `docs/development/operating-notes.md`, `UsageProbe/README.md`, and this plan after implementation. The user creates any PR manually.

## Figma acceptance contract

| Evidence required before coding | Required outcome |
| --- | --- |
| A Figma `/design/` or `/file/` URL with a Permissions node, or selected Desktop node | Record its file key and node ID. Reject prototype and FigJam links. |
| `get_metadata`, `get_design_context`, screenshot, variable definitions, and Code Connect lookup | Record dimensions, spacing, type, light/dark tokens, states, Context Rail presence, and existing mapped components. |
| Asset inventory | Classify every non-text visual as `download`, `code`, or `remote`. Export Figma-owned non-system assets as valid PNGs; system permission chrome may use approved SF Symbols. |
| Explicit user decision | Accept the ADD/UPDATE/REMOVE audit before production source changes. |

| Figma element | Accepted native adaptation |
| --- | --- |
| Permissions sidebar destination | Add `SettingsTab.permissions`; keep the existing sidebar, search, width, tint pattern, and single-window owner. |
| Status cards and action buttons | Use `SettingsSection`, `SettingsSectionRow`, `SettingsPreferenceControlRow`, and native buttons. Do not hand-draw switches or dialogs. |
| Notification permission request | Reuse the existing Enable quota notifications operation; it remains subject to the existing master-switch and macOS authorization gates. |
| Accessibility access | Show current trust plus **Not required by the current app**; do not prompt or imply degraded app behavior. |
| Login Items | Reuse `LaunchAtLoginController` and its native Login Items action. |
| Context Rail | Add one only if the accepted node includes it; otherwise do not fabricate a preview. |

## File structure

| File | Responsibility |
| --- | --- |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AccessibilityPermissionController.swift` | Read-only Accessibility trust status and explicit system-pane navigation. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PermissionsSettingsView.swift` | Scrollable native page with Notifications, Accessibility, and Login Items sections. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PermissionsSettingsContextView.swift` | Accepted Context Rail summary only when the Figma gate approves one. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsTab.swift` | Add title, SF Symbol, and tint for `.permissions`. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift` | Own and route one `AccessibilityPermissionController`. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift` | Route `.permissions` to its page. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift` | Route to Context Rail only if accepted. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` | Expose one-shot existing notification-state refresh. |
| Modify product/operating documentation | Record accepted Figma evidence, exact ownership, privacy boundary, and manual evidence. |

---

### Task 1: Accept the Figma Permissions design and native adaptation

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-dedicated-permissions-settings.md`
- Do not modify application source.

**Interfaces:**
- Consumes one user-supplied Figma Permissions node.
- Produces an accepted screenshot, token inventory, asset inventory, and ADD/UPDATE/REMOVE audit in this plan.

- [ ] **Step 1: Obtain the source node.**

Accept only a `/design/` or `/file/` URL containing one Permissions screen, or a selected Figma Desktop node. For a multi-screen root, first run `get_metadata` and record the selected child ID.

- [ ] **Step 2: Capture design evidence.**

Run, in order:

```text
get_metadata(fileKey, nodeId)
get_design_context(fileKey, nodeId, "generate for macOS using native SwiftUI")
get_screenshot(fileKey, nodeId)
get_variable_defs(fileKey, nodeId)
get_code_connect_map(fileKey, nodeId)
```

Record exact layout dimensions, card/row spacing, typography, color tokens, control states, Context Rail presence, and asset node IDs.

- [ ] **Step 3: Complete and accept the adaptation audit.**

Record these decisions and obtain user acceptance:

| Category | Decision |
| --- | --- |
| ADD | Permissions destination; notification, Accessibility, and Login Items status rows; accepted Context Rail only. |
| UPDATE | Sidebar result count and detail/preview switch routing. |
| REMOVE | Automation, Screen Recording, Full Disk Access, credential access, generic privacy scan, or unsupported Figma controls. |
| ADAPT | Figma cards/buttons become existing native Settings cards/buttons; macOS owns permission prompts and system panes. |

Do not continue until this table and any visual deviation are accepted.

### Task 2: Add read-only permission state owners and reuse existing actions

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AccessibilityPermissionController.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Produces `AccessibilityPermissionController.isTrusted`, `refresh()`, and `openSystemSettings()`.
- Produces `QuotaViewModel.refreshNotificationAuthorization()` without exposing `QuotaNotifier` or duplicating authorization logic.

- [ ] **Step 1: Add the Accessibility controller with no request API.**

```swift
import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityPermissionController: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
```

Do not call `AXIsProcessTrustedWithOptions`, do not pass a prompt option, and do not make trust a precondition for monitoring, login, menu, or refresh work.

- [ ] **Step 2: Expose existing notification refresh through the view model.**

```swift
func refreshNotificationAuthorization() {
    Task { [weak self] in
        guard let self else { return }
        _ = await monitor.refreshNotificationAuthorization()
    }
}
```

Keep `setAlertsEnabled(_:)` and `openNotificationSettings()` as the only request/recovery actions. No Settings view instantiates `UNUserNotificationCenter`.

- [ ] **Step 3: Compile the ownership slice.**

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor`.

Expected: `Build complete!`. Do not add an automated test case.

### Task 3: Implement the Permissions page and destination routing

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PermissionsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsTab.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`

**Interfaces:**
- Consumes `QuotaViewModel`, `LaunchAtLoginController`, and `AccessibilityPermissionController`.
- Produces `SettingsTab.permissions` and a scrollable native Settings page.

- [ ] **Step 1: Add `.permissions` after `.notifications`.**

Preserve all existing cases, values, titles, icons, and tints; add:

```swift
case permissions

case .permissions: "Permissions"
case .permissions: "checkmark.shield.fill"
case .permissions: .teal
```

- [ ] **Step 2: Give `SettingsView` the one controller instance.**

Add beside `launchAtLogin`:

```swift
@StateObject private var accessibilityPermission = AccessibilityPermissionController()
```

Pass it through `SettingsDetailView`; do not construct it in page, sidebar, Context Rail, or menu bodies.

- [ ] **Step 3: Add the detail route.**

```swift
case .permissions:
    PermissionsSettingsView(
        viewModel: viewModel,
        launchAtLogin: launchAtLogin,
        accessibilityPermission: accessibilityPermission
    )
```

- [ ] **Step 4: Build the three sections with shared rows.**

Use `SettingsPage`, `SettingsSection`, and `SettingsSectionRow`. Each leading label/description and trailing button uses `SettingsPreferenceControlRow`:

```swift
SettingsPreferenceControlRow("Quota notifications", description: notificationDescription) {
    Button(notificationActionTitle, action: notificationAction)
}

SettingsPreferenceControlRow(
    "Accessibility access",
    description: "Not required by the current app. macOS access is shown only so you can review the system setting."
) {
    Button("Open Accessibility Settings…", action: accessibilityPermission.openSystemSettings)
}

SettingsPreferenceControlRow(
    "Launch at Login",
    description: launchAtLogin.guidanceMessage ?? "Controls whether the signed app starts after you sign in to this Mac."
) {
    Button("Open Login Items…", action: launchAtLogin.openSystemSettings)
}
```

`notificationActionTitle` is **Enable quota notifications** for `.notDetermined`/`.unknown`, **Open Notification Settings…** for `.denied`, and **Open Notification Settings…** for `.authorized`/`.unavailable`. Its action calls only the matching existing `QuotaViewModel` method. Display the existing `NotificationAuthorizationState.statusMessage` exactly when available.

Accessibility displays **Granted** if trusted, otherwise **Not granted — not required**; it never asks for permission. Login Items displays `LaunchAtLoginController` status/guidance and never toggles registration from this status page.

- [ ] **Step 5: Refresh only at semantic boundaries.**

```swift
.onAppear {
    viewModel.refreshNotificationAuthorization()
    launchAtLogin.refresh()
    accessibilityPermission.refresh()
}
```

After a button action returns, refresh only its matching existing owner once. Do not add polling, timer, `onChange` loop, or automatic request.

### Task 4: Port an accepted Context Rail only, then document and verify

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PermissionsSettingsContextView.swift` only if Task 1 accepts it.
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift` only if Task 1 accepts it.
- Modify: `docs/product/follow-ups.md`, `docs/product/planning-board.md`, `docs/development/operating-notes.md`, `UsageProbe/README.md`, and this plan.

**Interfaces:**
- Produces no new persistence, request, timer, network access, or navigation owner.

- [ ] **Step 1: Add a Context Rail only if the accepted Figma screenshot has one.**

If accepted, use `SettingsContextCard` and `SettingsContextValueRow` for compact Notifications, Accessibility, and Login Items values. No switch, request button, or second controller appears in the rail. If absent from Figma, create no context view and record that decision.

- [ ] **Step 2: Audit width before adding actions.**

At the hidden-rail Settings Page width, verify:

```text
settingsPageWidth - 2 × pageHorizontalPadding - 2 × sectionContentHorizontalPadding
>= preferenceControlMinimumTextWidth + rowSpacing + widest action button
```

If labels exceed the budget, wrap their description and retain native button width. Do not shrink the window, introduce local padding, or create a custom compact action control.

- [ ] **Step 3: Update user-facing and product documentation.**

Move Follow-up 6 to **Verification** only after implementation. State that Notifications use the existing alert authorization flow, Login Items use `SMAppService`, Accessibility is read-only/not required, and no other macOS privacy pane is shown. Record the accepted Figma node/screenshot and every deliberate native deviation.

- [ ] **Step 4: Run regression baseline and signed build.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
git diff --check
```

Expected: existing regression suite passes, signed app verifies, plist lint returns `OK`, and diff has no whitespace errors. Do not claim a new regression test.

- [ ] **Step 5: Perform direct signed-app acceptance.**

Inspect all seven Settings destinations with Context Rail hidden and visible. On Permissions, inspect notification states naturally available without resetting macOS permission; denied recovery opens the native pane; Login Items reports `SMAppService` state without changing a user-owned setting; Accessibility opens only on click and remains optional. Check default size, long descriptions, scrolling, sidebar search, keyboard, VoiceOver, focus, Light/Dark, native-menu appearance boundary, and screenshot-to-port differences. Record each unobservable state as **Not run**; do not manufacture quota use or reset a permission merely to complete the matrix.

## Acceptance criteria

- A Figma node, screenshot, tokens, asset inventory, and user-approved adaptation audit exist before any Figma-port claim.
- Permissions is a seventh destination that preserves the existing Settings shell, width, search, appearance ownership, and Context Rail behavior.
- Notifications, Accessibility, and Login Items appear together with current status, purpose, limitation guidance, and accurate native actions.
- Notification authorization remains owned by `QuotaNotifier`/`QuotaMonitor`; Login Items remains owned by `LaunchAtLoginController`; Accessibility is read-only and optional.
- No new permission is requested automatically; no credentials, network access, dependency, or persistence schema is added; unsupported privacy panes remain absent.
- Signed-app visual evidence covers conditional states, long text, scrolling, keyboard/VoiceOver, and Light/Dark without inferring unobserved behavior.
- Existing automated checks are regression baseline only; no broad test suite is added.

## Plan self-review

- **Coverage:** Tasks 1–4 cover Figma acceptance, destination routing, the three approved permission areas, privacy/ownership boundaries, documentation, regression baseline, and manual acceptance.
- **Intentional exclusion:** There is no task for Automation, Screen Recording, Full Disk Access, credential access, speculative provider permissions, a permission timer, or custom system dialogs because current app behavior does not require them.
- **Blocking decision:** Until the user supplies and accepts a concrete Figma Permissions node, this is a native product plan and must not be described as an implemented Figma port.
