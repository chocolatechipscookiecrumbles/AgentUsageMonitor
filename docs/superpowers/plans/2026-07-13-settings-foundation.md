# Settings Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not create or run automated tests for this branch.

**Goal:** Expand the existing macOS Settings window into a durable six-tab foundation—General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics—without implementing later adaptive-refresh, sign-in, launch-at-login, export, or deletion behavior early.

**Architecture:** Preserve the app's lightweight MVVM structure. `AppSettings` remains the only persisted-preference owner; `QuotaMonitor` owns refresh and diagnostic effects; `QuotaViewModel` publishes a provider-neutral `SettingsStatus`; small SwiftUI tab views render bindings, real actions, or explicitly read-only status. No Settings view reads `UserDefaults`, JSON files, provider RPCs, or raw errors directly.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, Foundation, AppKit, macOS 14+, existing JSON stores; no third-party dependencies.

## Global Constraints

- Codex first; do not add Claude or GitHub Copilot behavior.
- Do not read `auth.json`, credentials, email, prompts, raw provider responses, or raw diagnostic errors.
- Do not create or run automated tests; verify with fresh signed-app builds, read-only state inspection, and manual UI acceptance.
- Keep `AppSettings` as the only module that reads and writes persisted preferences.
- Every interactive control must change real current behavior; future controls remain absent until their implementation branch.
- General, Refresh, Agents, Data & Privacy, and Diagnostics may show read-only status for deferred features.
- Keep notification thresholds fixed at 50%, 25%, 10%, and 5%.
- Do not add export, delete, logout, account switching, adaptive refresh choices, or launch-at-login controls.
- Preserve the user's 600-point Settings window width and native macOS `Form`, `Section`, `LabeledContent`, and tab presentation.
- Update `outline.md`, `how-to.md`, `UsageProbe/README.md`, the daily-driver roadmap, and this plan whenever behavior or documented status changes.

---

### Task 1: Define the Settings navigation and read-only status contract

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsTab.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsStatus.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LocalDataInventory.swift`

**Interfaces:**
- Consumes: `QuotaPresentation`, `RefreshState`, and `RefreshDiagnosticSummary`.
- Produces: `SettingsTab`, `SettingsStatus.make(...)`, `CodexAgentStatus`, and `LocalDataInventory.stores` for later view tasks.

- [x] **Step 1: Expand Settings tabs with stable labels and symbols**

Replace `SettingsTab` with a `CaseIterable`, `Identifiable` enum whose order is General, Notifications, Refresh, Agents, Data & Privacy, Diagnostics:

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case notifications
    case refresh
    case agents
    case dataPrivacy
    case diagnostics

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .notifications: "Notifications"
        case .refresh: "Refresh"
        case .agents: "Agents"
        case .dataPrivacy: "Data & Privacy"
        case .diagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gear"
        case .notifications: "bell"
        case .refresh: "arrow.clockwise"
        case .agents: "person.3"
        case .dataPrivacy: "hand.raised"
        case .diagnostics: "stethoscope"
        }
    }
}
```

- [x] **Step 2: Define provider-neutral Settings status**

Create `SettingsStatus.swift` with:

```swift
import Foundation

enum CodexAgentStatus: Sendable {
    case connected
    case cached
    case unavailable

    var displayName: String {
        switch self {
        case .connected: "Connected"
        case .cached: "Last confirmed account cached"
        case .unavailable: "Not currently detected"
        }
    }
}

struct SettingsStatus: Sendable {
    let appVersion: String
    let buildNumber: String
    let codexStatus: CodexAgentStatus
    let planName: String?
    let confirmation: ConfirmationState
    let collectedAt: Date
    let refreshState: RefreshState
    let diagnostics: RefreshDiagnosticSummary

    static func make(
        presentation: QuotaPresentation,
        refreshState: RefreshState,
        diagnostics: RefreshDiagnosticSummary,
        bundle: Bundle = .main
    ) -> SettingsStatus {
        let codexStatus: CodexAgentStatus
        if presentation.accountFingerprint != nil,
           presentation.confirmation == .confirmed || presentation.confirmation == .confirmedAfterRetry {
            codexStatus = .connected
        } else if presentation.accountFingerprint != nil,
                  presentation.confirmation == .cachedLastKnownGood {
            codexStatus = .cached
        } else {
            codexStatus = .unavailable
        }
        return SettingsStatus(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local",
            codexStatus: codexStatus,
            planName: presentation.planType?.capitalized,
            confirmation: presentation.confirmation,
            collectedAt: presentation.collectedAt,
            refreshState: refreshState,
            diagnostics: diagnostics
        )
    }
}
```

The status must never expose `accountFingerprint`, raw `detail`, email, file contents, or provider error strings.

- [x] **Step 3: Define the local-data inventory as documentation data**

Create `LocalDataInventory.swift` with `LocalDataStoreDescriptor` rows for:

```swift
import Foundation

struct LocalDataStoreDescriptor: Identifiable, Sendable {
    let id: String
    let title: String
    let fileName: String
    let retention: String
    let contents: String
}

enum LocalDataInventory {
    static let directory = "~/Library/Application Support/CodexUsageMonitor"
    static let stores = [
        LocalDataStoreDescriptor(
            id: "last-known-good",
            title: "Last confirmed quota",
            fileName: "last-known-good.json",
            retention: "Replaced by the next confirmed result",
            contents: "Hashed account identity and normalized quota fields"
        ),
        LocalDataStoreDescriptor(
            id: "quota-history",
            title: "Quota history",
            fileName: "quota-history.json",
            retention: "90 days, up to 500 observations",
            contents: "Confirmed normalized quota observations"
        ),
        LocalDataStoreDescriptor(
            id: "refresh-diagnostics",
            title: "Refresh diagnostics",
            fileName: "refresh-diagnostics.json",
            retention: "30 days, up to 1,000 outcomes",
            contents: "Timestamps, reasons, classified outcomes, and stable failure kinds"
        ),
    ]
}
```

- [x] **Step 4: Compile the status-contract slice**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh`

Expected: `Build complete!` and a signed `.build/CodexUsageMonitor.app`; do not run tests.

---

### Task 2: Publish live diagnostic status through monitoring and the UI adapter

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshDiagnosticsStore.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Consumes: existing privacy-safe `RefreshDiagnosticsStore.diagnosticSummary(from:through:)`.
- Produces: `QuotaMonitor.diagnosticSummary`, `QuotaViewModel.refreshState`, `QuotaViewModel.diagnosticSummary`, and `QuotaViewModel.settingsStatus`.

- [x] **Step 1: Add empty and display-safe diagnostic values**

Add `RefreshDiagnosticSummary.empty` and `RefreshOutcome.displayName`; keep raw errors unavailable to UI:

```swift
extension RefreshDiagnosticSummary {
    static let empty = RefreshDiagnosticSummary(outcomes: [:], failureKinds: [:])
}

extension RefreshOutcome {
    var displayName: String {
        switch self {
        case .confirmed: "Confirmed"
        case .confirmedAfterRetry: "Confirmed after retry"
        case .cachedLastKnownGood: "Cached last-known-good"
        case .unconfirmed: "Unconfirmed"
        case .unavailable: "Unavailable"
        }
    }
}
```

- [x] **Step 2: Publish a rolling 30-day summary from `QuotaMonitor`**

Add:

```swift
@Published private(set) var diagnosticSummary: RefreshDiagnosticSummary
```

Initialize it from the injected store for `Date.now - 30 days ... Date.now`, and recalculate it immediately after each diagnostic append. Keep all disk access inside `QuotaMonitor`/`RefreshDiagnosticsStore`.

- [x] **Step 3: Mirror monitoring status in `QuotaViewModel`**

Add published `refreshState` and `diagnosticSummary`, subscribe to the monitor's matching publishers, and expose:

```swift
var settingsStatus: SettingsStatus {
    SettingsStatus.make(
        presentation: presentation,
        refreshState: refreshState,
        diagnostics: diagnosticSummary
    )
}
```

Keep `isRefreshing` for the existing menu and derive it from the same `refreshState` subscription.

- [x] **Step 4: Compile the live-status slice**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh`

Expected: `Build complete!`; do not inspect diagnostic values, only confirm no raw fields were added to `SettingsStatus`.

---

### Task 3: Split the Settings window into focused native tab views

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`

**Interfaces:**
- Consumes: `QuotaViewModel`, `AppSettings`, `SettingsStatus`, and `LocalDataInventory`.
- Produces: one native macOS Settings scene with six focused tabs and no nonfunctional controls.

- [x] **Step 1: Extract the current notification form without changing behavior**

Move the existing notification `Form` and `minuteBinding` into `NotificationSettingsView`. Preserve every binding, the 50/25/10/5 copy, `LabeledContent` time controls, authorization recovery action, and the user's section spacing.

- [x] **Step 2: Make `SettingsView` a shallow tab composer**

Change its dependency to:

```swift
@ObservedObject var viewModel: QuotaViewModel
```

Compose six tab views with `.tabItem { Label(tab.title, systemImage: tab.systemImage) }`, `.tag(tab)`, and the existing `.frame(width: 600, height: 520)`. The Notifications tab receives `viewModel.settings`, `viewModel.setAlertsEnabled`, and `viewModel.openNotificationSettings`.

- [x] **Step 3: Add General and Refresh read-only views**

`GeneralSettingsView` shows app name, version/build, and “Codex first” provider scope using `Form`, `Section`, and `LabeledContent`.

`RefreshSettingsView` shows:

- current policy: “Every 5 minutes”;
- triggers: launch, wake, schedule, and manual;
- current activity from `RefreshState`;
- last collected time and confirmation;
- one real **Refresh now** button using `viewModel.refresh`, disabled while refreshing.

Do not add interval choices; those belong to `feature/adaptive-refresh`.

- [x] **Step 4: Add Agents and Data & Privacy read-only views**

`AgentsSettingsView` marks OpenAI Codex as the only current integration and shows its `CodexAgentStatus.displayName`, optional plan name, and confirmation. It also lists Claude Code and GitHub Copilot as planned and not connected. The view must explicitly say sign-in controls arrive in the Codex Connection phase and must not display an email or fingerprint.

`DataPrivacySettingsView` shows the local directory, each `LocalDataStoreDescriptor`, owner-only permissions (`0700` directory, `0600` files), and excluded sensitive content. Do not add reveal, export, or delete buttons.

- [x] **Step 5: Add the privacy-safe Diagnostics view**

`DiagnosticsSettingsView` shows the last refresh time, current confirmation, 30-day outcome counts in stable `RefreshOutcome` order, and classified failure-kind counts. When a dictionary is empty, render “No recorded outcomes” or “No classified failures” rather than zero-filled invented rows. Do not show raw provider errors or quota values.

- [x] **Step 6: Wire the Settings scene to the shared view model**

Replace the multi-argument `SettingsView` initializer in `CodexUsageMonitorApp` with:

```swift
Settings {
    SettingsView(viewModel: viewModel)
}
```

The menu's **Settings…** action continues selecting `.notifications`, activating the app, and calling the environment `openSettings()` action.

- [ ] **Step 7: Build and manually inspect all tabs**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh`

Then launch the signed app and manually confirm tab labels fit, Forms remain readable at 600×520, no fingerprint/raw error is visible, and **Refresh now** disables during collection.

---

### Task 4: Verify Settings-window focus and keyboard behavior

**Files:**
- Modify only if acceptance finds a defect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Modify only if acceptance finds a defect: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`

**Interfaces:**
- Consumes: existing `@Environment(\.openSettings)` action and `Settings` scene.
- Produces: one focused Settings window from repeated menu and keyboard opens.

- [ ] **Step 1: Verify repeated menu opens**

Open **Settings…**, return to the menu, and open **Settings…** again. Expected: the existing window comes to the front on Notifications; no second Settings window appears.

- [ ] **Step 2: Verify `Command-,`**

With the app active, press `Command-,`. Expected: the same Settings scene opens or focuses without creating another window.

- [ ] **Step 3: Keep any correction surgical**

If focus fails, preserve the existing sequence:

```swift
viewModel.settings.selectedSettingsTab = .notifications
NSApp.activate(ignoringOtherApps: true)
openSettings()
```

Do not replace the native Settings scene with a custom `NSWindow` controller.

---

### Task 5: Document and close the Settings-foundation branch

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-foundation.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: completed UI behavior and manual acceptance findings.
- Produces: user-facing instructions and an accurate roadmap checkpoint.

- [x] **Step 1: Document each tab and its current boundaries**

State that Refresh, Agents, Data & Privacy, and Diagnostics are read-only except the real **Refresh now** action; Agents lists Codex as current and Claude Code/GitHub Copilot as planned, while adaptive scheduling, sign-in, export/delete, and launch at login remain later branches.

- [x] **Step 2: Record privacy and retention presentation**

Document that Settings displays retention and classified outcome summaries but never fingerprints, emails, credentials, prompt data, raw RPC responses, or raw provider errors.

- [x] **Step 3: Update branch status**

Mark `feature/settings-foundation` active/complete as appropriate in the daily-driver roadmap and `outline.md`; do not mark later branches started.

- [x] **Step 4: Run final verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
git diff --check
git status --short --branch
```

Expected: signed app build succeeds, `git diff --check` emits nothing, and status lists only intentional Settings-foundation and documentation files. Do not run automated tests.

## Self-review

- Spec coverage: all five requested future-facing areas plus the existing Notifications tab have concrete tasks; one-window focus, `Command-,`, real-control behavior, retention, and privacy are covered.
- Scope control: adaptive interval controls, Codex sign-in, launch at login, export/delete, account switching, dashboard, and provider expansion remain absent.
- Type consistency: `SettingsStatus` is produced by `QuotaViewModel`, diagnostic summaries remain owned by monitoring, and every tab consumes only declared interfaces.
- Architecture fit: MVVM is a fit because this is a small multi-tab SwiftUI feature with moderate observable state and existing `ObservableObject` conventions; no architecture migration or dependency is justified.
- Verification: the branch uses signed builds and manual acceptance instead of prohibited automated tests.
