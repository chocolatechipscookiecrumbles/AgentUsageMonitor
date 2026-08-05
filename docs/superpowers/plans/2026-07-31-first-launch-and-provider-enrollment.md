# First Launch and Provider Enrollment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Use `swift-architecture-skill`, `swiftui-pro`, and `writing-for-interfaces` for the UI tasks. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dismissible three-page first-run window and require independent, explicit app-local enrollment before Codex or Claude monitoring begins.

**Architecture:** **Fit — MVVM + Coordinator.** MVVM matches the existing observable presentation model and keeps the tour's page state testable; a small AppKit-backed Coordinator is the secondary pattern that owns the one startup window and its lifecycle. `ProviderEnrollmentStore` is the single app-local consent owner, while existing connection controllers, quota monitors, and `LocalActivityMonitor` retain their separate operational state.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (`NSWindowController`, `NSHostingView`, `NSApplicationDelegate`), Foundation `UserDefaults`, XCTest. No new dependency.

## Global Constraints

- Persist `ProviderEnrollmentState` per provider as `.notRequested`, `.enabled`, or `.disabled`; never infer it from CLI status, cached quota, local files, or a Keychain item.
- Persist onboarding acknowledgement as a versioned integer. Closing, Skip, and the final action acknowledge the current tour version but do not change either provider enrollment.
- An absent enrollment key in the first post-0.0.1 build resolves to `.notRequested`, even when `codex.disconnected` or `claude.disconnected` was absent/false. This is the deliberate reconnect-once migration because 0.0.1 never stored explicit consent.
- Before `.enabled`, do not start that provider's quota monitor, connection polling, activation watcher, local file observer, scan, status-line discovery, cache presentation, or notifications.
- Selecting Connect changes only that provider to `.enabled`, then begins its controller flow. A failed external login leaves enrollment enabled and exposes provider-specific recovery; Disconnect changes it to `.disabled`, stops its owners, and purges its app-owned derived Token Monitor cache without signing out the provider CLI.
- Preserve the tab strip, stable provider-content host, 340-point non-scrolling menu, intrinsic provider height, shared footer gap, and current hit targets. Do not add selection identity or an animation workaround.
- The tour window must be closable, keyboard navigable, VoiceOver-labelled, centered, and readable in Light and Dark. It must not add a permanent Dock presence to this `LSUIElement` app.
- Supplied images are release inputs. Accept only assets with confirmed redistribution rights, one image per named slot, and a concise accessibility description. Do not ship unlabeled decorative placeholders as final media.
- No broad onboarding or routing tests. The released implicit-connection defect gets the smallest deterministic launch-policy regression; visual/navigation behavior is signed-app acceptance.

## File Structure

### Create

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ProviderEnrollmentState.swift` — provider enrollment vocabulary and policy projection.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ProviderEnrollmentStore.swift` — versioned `UserDefaults` persistence and 0.0.1 migration.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Onboarding/OnboardingPage.swift` — page IDs, final copy, asset names, and accessibility descriptions.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Onboarding/OnboardingViewModel.swift` — current index and Back/Continue/Skip/Finish intents.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Onboarding/OnboardingView.swift` — pure SwiftUI tour rendering.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Onboarding/StartupCoordinator.swift` — one `NSWindowController` and acknowledgement lifecycle.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/ApplicationDelegate.swift` — shared composition root and launch presentation.
- `CodexUsageMonitor/Resources/Assets.xcassets/OnboardingWelcome.imageset/` — user-supplied welcome artwork.
- `CodexUsageMonitor/Resources/Assets.xcassets/OnboardingProviders.imageset/` — user-supplied provider-choice artwork.
- `CodexUsageMonitor/Resources/Assets.xcassets/OnboardingPrivacy.imageset/` — user-supplied local/private artwork.

### Modify

- `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexUnavailableContent.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeUnavailableContent.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift`
- `CodexUsageMonitor/Tests/CodexUsageMonitorTests/QuotaViewModelLaunchPolicyTests.swift`
- `docs/adr/0001-read-local-token-activity-automatically.md`
- `UsageProbe/README.md`
- `docs/development/operating-notes.md`
- `docs/product/follow-ups.md`
- `docs/product/planning-board.md`

## Interfaces

```swift
enum ProviderEnrollmentState: String, Codable, Equatable, Sendable {
    case notRequested
    case enabled
    case disabled
}

@MainActor
final class ProviderEnrollmentStore: ObservableObject {
    @Published private(set) var states: [AgentProvider: ProviderEnrollmentState]
    func state(for provider: AgentProvider) -> ProviderEnrollmentState
    func enable(_ provider: AgentProvider)
    func disable(_ provider: AgentProvider)
}

struct ProviderRuntimePolicy: Equatable, Sendable {
    let mayCheckAccount: Bool
    let mayRefreshQuota: Bool
    let mayCollectLocalActivity: Bool
    let showsConnectOnly: Bool
}
```

`ProviderRuntimePolicy` is derived from enrollment plus the existing Token Monitor visibility preference. It is not another persisted state owner.

## Implementation status — 2026-08-04

Tasks 1–4 are implemented on `feat/first-launch-and-provider-enrollment`;
`swift build` and the full
335-test suite exit 0 (1 pre-existing skip: `MenuBarProviderGlyphTests`, which
probes the untracked asset catalog). Task 5's signed-app matrix is **not run** —
see Verification status below.

Four deliberate deviations from the plan as written:

1. **Bottom-row controls replace Back/Continue/Skip/Done.** Per direction on
   2026-08-04 the tour's single control row is: back arrow, three-dot page
   indicator, forward arrow, then one trailing `Dismiss` button. `Dismiss` keeps
   the same label on every page because it always does the same thing. Escape
   maps to it via `.keyboardShortcut(.cancelAction)`; Left/Right arrow keys drive
   the pages through `.onKeyPress`, which yields to any focused control so Tab
   navigation is unchanged.
2. **`ProviderConnectCard` instead of a connect-only mode inside
   `CodexUnavailableContent` / `ClaudeUnavailableContent`.** Those two views
   render a *connection* state, and reaching one implies the app has already
   asked the provider something. Before enrollment it has asked nothing, so one
   shared card with no state machine behind it is both the honest model and the
   only way the two tabs cannot drift. The rendered title, body, and button copy
   are exactly as specified.
3. **`ProviderMenuMode` has `.connectOnly` and `.operational`, no `.recovery`.**
   Recovery is already owned by each provider's existing connection state inside
   the operational content; a third case would have been unreachable.
4. **The regression is at the policy layer, not injected spies inside
   `QuotaViewModel`.** `QuotaViewModel` constructs `QuotaMonitor`,
   `ClaudeUsageMonitor`, `LocalActivityMonitor`, and both controllers inline as
   concrete types; protocol-ising all five to spy on them is a larger refactor
   than the defect warrants and is exactly the broad-coverage work `AGENTS.md`
   prohibits. Instead `QuotaViewModelLaunchPolicyTests` pins the decision every
   owner now consults — fresh install and 0.0.1-upgrade defaults, no write on
   read, per-provider independence, and tour acknowledgement not enrolling —
   while the existing `LocalActivityMonitorRegressionTests` already prove a
   disabled provider performs no scan and retains no cache. **Honest limitation:**
   these tests cannot be run against the pre-change build, because the types they
   exercise did not exist in it. They protect the fix; they do not re-demonstrate
   the released failure.

## Task 1 — Persist explicit provider enrollment and reproduce the release defect

- [x] **Step 1: Add the narrow failing regression.** Extend `QuotaViewModelLaunchPolicyTests` with a fresh `UserDefaults(suiteName:)` and injected spies proving that absent enrollment keys yield `.notRequested` for Codex and Claude, call neither account reader, start neither quota collector, and do not schedule local scans even when both fake CLIs report signed in.
- [x] **Step 2: Run the regression.** Run `swift test --package-path CodexUsageMonitor --filter QuotaViewModelLaunchPolicyTests`; expect failure because `AppSettings` currently defaults both disconnect booleans to false and `QuotaViewModel.start()` starts every owner.
- [x] **Step 3: Add `ProviderEnrollmentState`, `ProviderRuntimePolicy`, and `ProviderEnrollmentStore`.** Store keys as `provider.enrollment.codex` and `provider.enrollment.claude-code`; treat missing/unknown values as `.notRequested`; never write a default merely by reading it.
- [x] **Step 4: Add versioned onboarding state to `AppSettings`.** Use `onboarding.acknowledgedVersion`, `static let currentOnboardingVersion = 1`, `needsOnboarding`, and `acknowledgeCurrentOnboarding()`; keep this non-secret state in `UserDefaults`.
- [x] **Step 5: Remove the ambiguous boolean as authority.** Keep `codex.disconnected` and `claude.disconnected` only as one-release cleanup inputs, then stop reading/writing them once the enrollment migration is committed.
- [x] **Step 6: Re-run the regression.** Expected: the fresh state stays unenrolled without any provider call.
- [x] **Step 7: Commit.** Commit enrollment vocabulary, persistence, and the one regression together.

## Task 2 — Gate each runtime owner without merging their state

- [x] **Step 1: Inject the enrollment store into `QuotaViewModel`.** Add an initializer used by tests and a live convenience initializer; retain one store shared by menu, Settings, quota owners, and local-activity policy.
- [x] **Step 2: Replace unconditional startup.** In `start()`, evaluate providers independently: start Codex connection/quota only when Codex enrollment is enabled; start Claude connection/usage only when Claude enrollment is enabled; start `LocalActivityMonitor` once but call `setCollectionEnabled(enrollment == .enabled && tokenMonitorVisible, for:)` before `start()`.
- [x] **Step 3: Add explicit intents.** Implement `connectCodex()`, `connectClaude()`, `disconnectCodex()`, and `disconnectClaude()`. Connect persists only the selected provider before invoking its existing controller; Disconnect stops that provider, clears its transient presentation, disables/purges its local activity through the existing privacy path, and leaves the external CLI untouched.
- [x] **Step 4: Gate every trigger.** Scheduled refresh, wake, manual refresh, activation recheck, refresh-failure recheck, and notification evaluation must return before provider work when enrollment is not enabled. A footer Refresh on a connect-only tab is disabled rather than silently enrolling.
- [x] **Step 5: Preserve independent local state.** Once enrolled, a quota sign-in failure may coexist with `.available` Token Monitor data. Do not map local read failures into `AgentConnectionState` or `ClaudeConnectionState`.
- [x] **Step 6: Amend ADR 0001.** Record that local reads are now automatic only for explicitly enrolled providers, why the consent boundary changed after 0.0.1, and that Token Monitor remains operationally separate from quota.
- [x] **Step 7: Run the narrow launch-policy test and existing local-activity privacy regressions.** Expected: all exit 0.

## Task 3 — Make unenrolled provider tabs connect-only

- [x] **Step 1: Define one UI projection.** Add a pure `ProviderMenuMode` with `.connectOnly`, `.operational`, and `.recovery`; derive it from enrollment first, then existing provider states. Enrollment always wins over cached data.
- [x] **Step 2: Update Codex content.** In `.connectOnly`, render one `CodexUnavailableContent` whose title is `Connect Codex`, body is `Connect Codex to show quota and local activity from this Mac.`, and primary button is `Connect Codex`. Do not render `activityCard`, cached strips, quota cards, permission strips, or sign-in-method buttons until the explicit Connect intent has run.
- [x] **Step 3: Update Claude content.** In `.connectOnly`, render one `ClaudeUnavailableContent` whose title is `Connect Claude`, body is `Connect through Claude Code to show quota and local activity. The connection may ask for Keychain access.`, and primary button is `Connect Claude`.
- [x] **Step 4: Keep global chrome stable.** Preserve both tabs, provider header, shared footer, intrinsic-height host, selector hit regions, and last-selected tab persistence. Header status reads `Not connected` without probing either provider.
- [x] **Step 5: Mirror the state in Settings.** Agent pages show the same Connect action and disclosure before operational settings. They must not display old cached values as though the provider were enrolled.
- [ ] **Step 6: Manual regression boundary.** With each combination of provider enrollment, verify the other tab does not move or mutate; run 20 pointer switches, keyboard switching, and VoiceOver switching in the signed app.

## Task 4 — Build the dismissible three-page onboarding window

- [ ] **Step 1: Receive and validate the three images.** Map them exactly to `OnboardingWelcome`, `OnboardingProviders`, and `OnboardingPrivacy`; confirm redistribution rights, vector/retina quality, Light/Dark behavior, and accessibility descriptions before adding them to the asset catalog.
- [x] **Step 2: Add the page catalog with final copy.** Use these pages:

  1. `Welcome to Agent Monitor` — `Keep Codex and Claude usage one click away in the menu bar.`
  2. `Connect only what you use` — `Codex and Claude start disconnected. Connect each provider separately when you’re ready.`
  3. `Local and private` — `Token Monitor reads supported usage fields on this Mac. It does not collect prompts or responses.`

  Use `Skip` throughout, `Back` after page one, `Continue` on pages one and two, and `Done` on page three. `Done` closes the tour and leaves Agent Monitor running in the menu bar; the first menu-bar click opens the connect-only tabs. Do not label the button `Open Agent Monitor` unless the app gains a supported way to programmatically open `MenuBarExtra`.
- [x] **Step 3: Implement `OnboardingViewModel`.** It owns only `currentPageIndex` and emits `onAcknowledge` for Skip, window close, and final completion. Cancel any outstanding task in `deinit`; the tour performs no network, Keychain, or provider operation.
- [x] **Step 4: Implement `OnboardingView`.** Use a fixed 760 × 520 content budget, an image region that scales down without cropping essential content, a page indicator, explicit focus order, Escape/close support, reduced-motion-aware transitions, and accessibility labels for every meaningful image/control.
- [x] **Step 5: Implement `StartupCoordinator`.** Own one retained `NSWindowController`; center and activate the app on `start()` only when `needsOnboarding`; use `NSHostingView` for the SwiftUI content; route both `windowShouldClose` and view callbacks through one idempotent acknowledgement method.
- [x] **Step 6: Add the composition root.** Move the stable `QuotaViewModel` ownership to `ApplicationDelegate`, expose the same instance to both `CodexUsageMonitorApp` scenes and `StartupCoordinator`, and preserve the two command-line probe early exits. Do not create a second settings or provider model for onboarding.
- [x] **Step 7: Add a visual-only launch argument.** `--show-onboarding-preview` forces presentation without writing acknowledgement or changing enrollment. It exists solely to re-open the signed window safely for visual acceptance and must not start provider monitoring when combined with the existing probe gates.
- [ ] **Step 8: Verify dismissal semantics.** Skip, close, and `Done` each close the audit-owned window, record acknowledgement exactly once in normal mode, leave the menu-bar item present, and never change provider enrollment. Relaunch does not reopen the tour; preview mode always does and never persists.

## Task 5 — Verification and documentation

- [x] Run `swift build --package-path CodexUsageMonitor`; **observed** exit 0. No new warnings; the only warnings are the pre-existing `kSecUseAuthenticationUI` deprecations in `ClaudeOAuthCredential.swift`.
- [x] Run `swift test --package-path CodexUsageMonitor --filter QuotaViewModelLaunchPolicyTests`; **observed** 7 tests, 0 failures.
- [x] Run the full existing test suite; **observed** 335 tests, 0 failures, 1 skip (`MenuBarProviderGlyphTests`, which probes the untracked asset catalog and skipped before this change too).
- [x] Run `git diff --check`; **observed** exit 0.
- [x] Update `docs/adr/0001-read-local-token-activity-automatically.md`, `UsageProbe/README.md`, `docs/development/operating-notes.md`, follow-up 13, the planning board, and this plan.
- [ ] Run the main macOS scheme with `xcodebuild`. **Not run.**
- [ ] Build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh`; verify with `verify-signed-app-resources.sh`. **Blocked in this checkout** — `.gitignore` excludes `CodexUsageMonitor/Resources/Assets.xcassets/` and all `*.png`, so `actool` has no catalog to compile and the script fails before signing. The onboarding imagesets inherit that boundary: like `AppIcon`, they are supplied out of band. `OnboardingView` renders a neutral placeholder region when an imageset is absent, so a fresh public clone still builds and the tour is still legible — but that placeholder is explicitly not shippable art.
- [ ] Inspect onboarding at 760 × 520 in Light and Dark, reduced motion on/off, 100% and enlarged text, keyboard-only, VoiceOver, close/Dismiss, preview mode, and relaunch. **Not run.** A `swift run CodexUsageMonitor --show-onboarding-preview` process was started, stayed alive 12 s without crashing, and was terminated; the screen was showing a screensaver, so nothing was actually seen. That is a liveness check, not visual acceptance.
- [ ] Exercise fresh and upgrade policy with both CLIs signed in, only one, neither, missing CLIs, and custom homes. Both providers must remain connect-only until their own Connect action. **Not run.**
- [ ] Verify connecting/disconnecting in both orders and after relaunch. No action for one provider may affect the other. **Not run.**
- [ ] Re-run the 20-cycle pointer, keyboard, and VoiceOver provider-switch matrix required by the selection-host geometry guardrails: this change alters what each tab renders. **Not run.**

### Verification status

Automated: complete and passing.

**Observed 2026-08-04 (user, `swift run --show-onboarding-preview`):** the tour
window presents, is centered, and its bottom row — back arrow, three-dot page
indicator, forward arrow, trailing **Dismiss** — behaves. Two known gaps, both
the same root cause and both deferred by direction:

- The three page images are absent, so each page shows the neutral placeholder
  region. Artwork is still to be supplied; see
  [`docs/design/onboarding-artwork.md`](../../design/onboarding-artwork.md) for
  slots, size (1328 × 646 px), format, and Light/Dark variants.
- **Icons do not load in an unpackaged run.** `Image(nsImage: NSImage(named:))`
  resolves through the compiled catalog in the app bundle, and `swift run` has no
  bundle — so this is expected there, but it is *also* currently unverifiable in a
  packaged build, because `Resources/Assets.xcassets/` (including
  `AppIcon.appiconset`) is excluded from this repository and `build-app.sh` fails
  at `actool` before signing. **Noted, fix deferred.** Restoring the catalog from
  the private copy is the prerequisite for every remaining visual check below.

Everything else is **unobserved**: Light/Dark, reduced motion, enlarged text,
keyboard-only and VoiceOver navigation, the connect-only tabs, and every
enrollment transition are source-correct and compile, and nothing more than that
is claimed.

## Adapted MVVM + Coordinator Review Checklist

- One enrollment store owns app-local consent; views and monitors do not infer it.
- The onboarding View renders state and emits intents; it does not persist or present windows.
- The onboarding ViewModel contains no AppKit, provider service, Keychain, or network code.
- `StartupCoordinator` owns only window/flow presentation and is retained for the full tour.
- Provider async work is cancellable and guarded by enrollment at every entry point.
- Local activity, quota, and connection states are not collapsed into one enum.
