# Codex Menu-Bar MVP Implementation Plan

> **For agentic workers:** Execute inline task-by-task. The user explicitly requested live/manual verification rather than generated test cases for this prototype.

**Implementation status (2026-07-12):** The first native MVP is implemented as a Swift package plus local app-bundle script, rather than a hand-authored `.xcodeproj`. It compiles with Xcode 26.3 and produced a confirmed live snapshot matching the Python reference. The user must still run the one-time `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` command to make Xcode 26.3 the system default.

**Functional follow-on (2026-07-13):** [Quota History Foundation](<USER_HOME>/Desktop/agent%20usage/docs/superpowers/plans/2026-07-13-quota-history-foundation.md) is implemented. `QuotaRepository` now shields application state from Codex collection/storage details, retains bounded confirmed history, and calculates future-UI forecasts without changing the menu source.

**Goal:** Build a native macOS menu-bar application that shows the currently confirmed Codex plan, credit balance, earned reset-credit expiries, five-hour quota, weekly quota, reset times, freshness, and confirmation state.

**Architecture:** Create one deep `CodexQuotaCollector` module with a single `refresh() async -> QuotaPresentation` interface. Its implementation owns process lifecycle, app-server JSON-RPC, three-sample confirmation, `codex` lane selection, account fingerprinting, and sanitized last-known-good persistence. SwiftUI and the menu-bar target consume only the presentation value, so they never see credentials, raw JSON-RPC, or subprocess details.

**Tech Stack:** Swift 6+, macOS 14+, SwiftUI `MenuBarExtra`, Foundation `Process`, `Codable`, `UserNotifications`; Python remains a local Phase 0 reference harness only.

## Global Constraints

- Ship a native Swift/SwiftUI macOS application; do not ship or embed the Python harness.
- Target Developer ID distribution outside the Mac App Store for this MVP.
- Require a repaired, consistent Xcode/Command Line Tools installation before Swift work; the current SwiftPM installation previously failed to load `llbuild`.
- Invoke only `codex app-server --listen stdio://` and read-only account methods; never send a model prompt, consume a reset credit, log out, or read `auth.json`.
- Store only a one-way account fingerprint and confirmed non-secret quota fields in Application Support with file protection appropriate to macOS.
- Do not generate test cases for this prototype. Verify each task through compilation, live read-only Codex responses, and visible menu-bar behavior.
- Update `how-to.md` and `UsageProbe/README.md` whenever a user-visible command, safeguard, field, or setup requirement changes.

---

## Why Swift, not Python or Electron

Use Swift for the app. The required product surfaces—`MenuBarExtra`, launch at login, native notifications, Keychain, WidgetKit, CloudKit, and a later Watch target—are first-class Apple frameworks. A Python or Electron shell would add packaging, startup, permission, code-signing, and native-extension complexity without simplifying the Codex protocol. Keep `UsageProbe/codex_probe` as the behavior reference until the Swift implementation produces matching live output.

## File map

| Path | Responsibility |
|---|---|
| `CodexUsageMonitor/Package.swift` | Swift package opened directly by Xcode |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift` | App entry point and `MenuBarExtra` declaration |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/` | UI-safe domain, read-only JSON-RPC collector, validator, and sanitized cache |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/` | Menu-bar presentation, refresh state, and scheduling |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift` | Opt-in, deduplicated native alerts |
| `CodexUsageMonitor/Resources/Info.plist` | Menu-bar app bundle identity/configuration |
| `CodexUsageMonitor/Scripts/build-app.sh` | Local bundle build command |
| `CodexUsageMonitor/Resources/Info.plist` | Menu-bar app configuration and usage descriptions only when required |

## Task 1: Repair the Swift toolchain and scaffold the app

**Files:**
- Create: `CodexUsageMonitor/CodexUsageMonitor.xcodeproj`
- Create: `CodexUsageMonitor/CodexUsageMonitorApp.swift`

**Interface:** The app launches as a menu-bar-only process and displays an “Unavailable” placeholder.

- [x] Verify Xcode 26.3 at `/Applications/Xcode.app`; system-wide selection remains a user-owned `sudo xcode-select` step.
- [x] Compile successfully with that toolchain (Swift 6.2.4).
- [x] Create the macOS 14 SwiftUI menu-bar package and local `.app` bundle script.
- [x] Replace the default window scene with `MenuBarExtra("Codex", systemImage: "gauge.with.dots.needle.33percent")` and an unavailable state.
- [ ] Launch the `.app` visibly from the user desktop and confirm the menu-bar icon; this requires the user-visible app launch.

## Task 2: Port the normalized quota domain

**Files:**
- Create: `CodexUsageMonitor/Quota/QuotaPresentation.swift`
- Create: `CodexUsageMonitor/Quota/CodexProtocolModels.swift`

**Interface:** `QuotaPresentation` contains `planType`, `creditBalance`, `availableResetCredits`, `resetCreditExpiryDates`, `fiveHour`, `weekly`, `confirmation`, `collectedAt`, and `source`.

- [x] Create `QuotaWindow` with `usedPercent`, computed `remainingPercent`, `resetAt`, and `durationMinutes`.
- [x] Create `QuotaPresentation` with unavailable fields and all five confirmation states.
- [x] Create the JSON-RPC requests for `initialize`, `initialized`, `account/read`, `account/rateLimits/read`, and `account/usage/read`.
- [x] Decode only the `codex` lane (with provider fallback), credits, reset-credit expiries, and email-derived fingerprint inside `Quota/`.
- [x] Compile with Xcode 26.3 / Swift 6.2.4 with zero errors.

## Task 3: Implement the read-only Codex app-server adapter

**Files:**
- Create: `CodexUsageMonitor/Quota/CodexAppServerSession.swift`

**Interface:** `func collectSample(codexExecutable: URL) async throws -> CodexQuotaSample` launches one bounded read-only app-server session and returns normalized data plus a one-way account fingerprint.

- [x] Launch `codex app-server --listen stdio://` with `Foundation.Process`.
- [x] Wait for the `initialize` response before sending the notification and read-only account requests.
- [x] Route newline-delimited responses by ID, ignore notifications, and terminate after responses or a 15-second timeout.
- [x] Hash the normalized account email with SHA-256 and retain only 16 hexadecimal characters.
- [x] Reject absent account identity, `codex` lane, or quota windows rather than guessing.
- [x] Compare live Swift output with `python3 -m codex_probe --json`: all requested fields matched; the five-hour percentage moved one point during the 12-second gap.

## Task 4: Implement confirmation and last-known-good storage

**Files:**
- Create: `CodexUsageMonitor/Quota/QuotaValidator.swift`
- Create: `CodexUsageMonitor/Quota/QuotaStateStore.swift`
- Create: `CodexUsageMonitor/Quota/CodexQuotaCollector.swift`

**Interface:** `func refresh() async -> QuotaPresentation` is the only collector interface used outside `Quota/`.

- [x] Collect three samples one second apart.
- [x] Reject the observed transient near-empty snapshot pattern.
- [x] Require a matching fingerprint, `codex` lane, reset timestamps within two minutes, and usage within five points.
- [x] Persist confirmed snapshots to `Application Support/CodexUsageMonitor/last-known-good.json` with `0700` directory and `0600` file permissions.
- [x] Return matching cached data as `cached-last-known-good`; otherwise return explicit `unconfirmed` or `unavailable` states.
- [x] Build, launch, and complete five live native confirmation reads; all confirmed. No generated test cases were created or run.

## Task 5: Build the menu-bar experience

**Files:**
- Create: `CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Create: `CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Modify: `CodexUsageMonitor/CodexUsageMonitorApp.swift`

**Interface:** The menu bar shows the lowest remaining window percentage; opening the menu reveals all requested fields and a manual refresh action.

- [x] Make `QuotaViewModel` own one collector, refresh task, and presentation value.
- [x] Refresh at launch and on explicit user request.
- [x] Display plan, credits, reset-credit expiries, both quota windows, reset times, freshness, and confirmation state.
- [x] Add a disabled-while-refreshing “Refresh now” action.
- [x] Render cached/unconfirmed data in amber and unavailable data in gray.
- [x] Build the app and compare every available collector field with the Python reference. Visible menu-bar inspection remains a user-desktop confirmation.

## Task 6: Add conservative refresh and notifications

**Files:**
- Modify: `CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Create: `CodexUsageMonitor/Notifications/QuotaNotifier.swift`

**Interface:** Refresh runs every five minutes only while the app is active; notifications are emitted exclusively for confirmed or cached-last-known-good data.

- [x] Add a five-minute active-app refresh timer and refresh after wake or a manual action.
- [x] Request notification permission only after the user enables alerts in the menu.
- [x] Add 25%, 10%, and 5% remaining alerts per window, deduplicated by reset timestamp and threshold.
- [x] Add earned-reset-credit-expiry alerts at 24 hours and one hour, deduplicated by expiry timestamp.
- [x] Never send an alert from `unconfirmed` or `unavailable` data.
- [ ] Leave background polling, widgets, CloudKit, Watch support, and other providers out of this MVP.

## Phase progression after the Codex MVP

1. **Codex MVP hardening:** Run the app for one week, record confirmation transitions and any fallback use, then revise thresholds from observed behavior.
2. **GitHub Copilot adapter:** Add a separate collector using the documented personal billing API; preserve the same `QuotaPresentation` interface.
3. **Claude local analytics:** Add local-history reporting first; keep personal quota retrieval experimental until its provider path is independently proven.
4. **History and forecasting:** Persist confirmed snapshots and calculate deterministic time-to-exhaustion.
5. **Widgets and private CloudKit:** Sync sanitized presentations only after the collection layer is stable.
6. **Watch/iPhone companion:** Consume CloudKit snapshots; never add provider credentials or collectors to those targets.

## Plan self-review

- Scope coverage: the plan builds only the already-proven Codex quota path and delays all other providers.
- Security coverage: no raw credentials, emails, prompts, or raw JSON leave the quota module; stored snapshots are non-secret.
- Platform coverage: SwiftUI menu bar, native notifications, and later Apple-platform expansion are supported by the selected stack.
- Validation coverage: each task has a concrete build or live read-only verification command or visible behavior; generated test cases are intentionally excluded by user direction.
