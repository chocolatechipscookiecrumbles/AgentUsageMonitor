# Claude Passive-First Monitoring Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` or `executing-plans` to implement this approved plan task by task. Track execution and verification below.

**Goal:** Keep Claude monitoring useful without dependable Keychain access or recurring permission dialogs during ordinary monitoring.

**Architecture:** Reuse `ClaudeUsageCollector` and existing enrollment, credential-controller, and monitor ownership. Fresh passive quota wins; OAuth is a silent best-effort secondary source; retained readings remain visible; explicit consented `/usage` is the only usage CLI recovery action.

**Tech stack:** Swift, SwiftUI, Security/LocalAuthentication, existing Swift package tests and signed macOS app build.

## Constraints and defaults

- Assume the status-line bridge works as intended. The [Keychain-grant diagnosis](../../development/claude-keychain-grant-durability.md) and [diagnostic plan](2026-09-01-claude-keychain-reprompt-durability.md) remain separate tasks; do not claim their root cause or grant durability is resolved.
- Keep combined Connect: enroll monitoring, configure passive capture using existing foreign-command safeguards, then attempt interactive credential validation. Denial, cancellation, or unavailable credentials must resume passive monitoring without undoing enrollment.
- No new coordinator, polling mechanism, dependencies, copied credentials, direct token renewal, automatic `/usage`, bridge redesign, or installation/release changes.
- Preserve cadence, coalescing, cancellation, enrollment gates, rate-limit backoff, and app-local Disconnect. Disconnect leaves provider credentials and foreign status-line commands untouched and prevents in-flight results from restoring cleared usage.

## 1. Collection and credential handling

- [x] Serve valid passive snapshots with at least one quota window when their age is at most two minutes; do not access credentials in that branch.
- [x] Otherwise use noninteractive Keychain OAuth subject to existing backoff. Scope the provider-owned legacy-store query to one default/login Keychain without altering the global search list or credential permissions.
- [x] Preserve typed credential errors through OAuth. Launch, menu opening, ordinary Refresh, schedules, and retries must never allow interaction; only explicit Connect/Reconnect may do so.
- [x] Remove delegated CLI renewal from ordinary Refresh. Expired/rejected tokens use fallback just like unavailable credentials.
- [x] Select the freshest usable older passive snapshot or cached reading with its original capture time; show unavailable plus explicit recovery when neither is usable.

## 2. Enrollment and presentation

- [x] Remove propagation of background usage credential failures into authorization-denied connection state. Existing enrollment expresses **Monitoring enabled** independently of live-fallback health; do not add another persisted connection flag.
- [x] Keep usable quota cards visible in `ClaudeMenuContent` during credential setup and after credential failures. Use concise status copy in the existing status area instead of replacing quota cards with recovery content.
- [x] Align menu, Agents Settings, and Context Rail wording: **Monitoring enabled**, **Live fallback unavailable**, source, and last updated. Do not present retained data as live or silent read failures as revoked permission.
- [x] Retain explicit Reconnect and the existing cost-disclosed `/usage` Settings action. Prevent duplicate CLI execution, publish/cache successful readings, and preserve the prior reading on failure.
- [x] Preserve shared Settings components, stable menu host, intrinsic provider height, and existing content-to-footer gap.

## 3. Regression and signed-app acceptance

Add automated coverage only for reproduced defects, preserving existing tests:

- [x] Protect enrollment and connection presentation from noninteractive credential failures with typed-error and enrolled cached-reading regressions. The former background failure subscription is removed.
- [x] Preserve passive/cached quota across credential failure; regression asserts quota values and original capture time survive. The menu no longer substitutes the credential-recovery card.
- [x] Build the main macOS scheme with `xcodebuild`, run narrow relevant existing tests, then build with `CodexUsageMonitor/Scripts/build-app.sh`. Record commands, exit statuses, warnings, and errors below.
- [x] Verify fresh passive, stale passive plus successful OAuth, unavailable Keychain, expired token, rate limiting, cache-only data, and no data. Do not add broad happy-path tests solely for this matrix.
- [ ] In the signed app inspect combined setup success and denial/cancellation, ordinary Refresh without prompting, explicit `/usage` success/failure, and Disconnect during an in-flight read. Do not manufacture destructive credential changes to force these states.
- [ ] Inspect affected menu and Settings states at default size with keyboard access, Light/Dark, and Context Rail hidden/visible. Record unobserved states explicitly rather than infer coverage from compilation.

## 4. Documentation and follow-up

- [x] Update authentication guidance, operating notes, `UsageProbe/README.md`, domain terminology, and this implementation record for passive-first behavior.
- [x] Correct the dashboard follow-up to **Astra and Claude Fable 5 and 5.1**. Model support is a note only; confirm exact provider identifiers before that separate implementation.
- [x] Keep existing diagnostic evidence and investigation scope separate; do not make passive-first implementation depend on Keychain-grant durability.

## Verification evidence and limitations

- Implementation is on `feat/claude-passive-first`, based on the existing Claude feature branch containing current public main. Existing diagnostic documentation edits were preserved; no push or PR was created.
- `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/claude-passive-xcode build`: exit 0, BUILD SUCCEEDED.
- `swift test --package-path CodexUsageMonitor --filter 'Claude|ProviderContextSummary'`: exit 0, 186 tests, zero failures. Existing cases cover source priority, missing/stale/cache-only readings, rejection and rate limits, CLI parsing/success/failure, enrollment, and disconnect behavior. Updated stale manual-prompt expectations and fixed an existing reconnect test to wait for publication rather than collector entry.
- Reproduced the in-flight-refresh/manual-result race with `testManualReadingSurvivesOlderInFlightFallback`: with the old behavior, one test failed two assertions (older OAuth/10 replaced manual CLI/25); after restoring generation invalidation, the relevant suite passed. Cache compare/write/delete now share a lock so older writes cannot win that race.
- Regression checks preserve typed silent credential failures, cached quota and its timestamp, enrollment presentation after credential failure, and cached quota after an empty OAuth result. Native interaction-policy checks inject flag operations and verify suppression/restoration, including failure paths; they do not manufacture a real denied provider credential.
- Compiler warnings: `SecKeychainGetUserInteractionAllowed`, `SecKeychainSetUserInteractionAllowed`, and `SecKeychainCopyDefault` are deprecated since macOS 10.10. They are intentionally isolated at the legacy provider-credential boundary. The query's LAContext alone is insufficient for that legacy path; both read policies share a synchronous lock, silent reads disable process-local interaction, and prior state is restored with checked OSStatus.
- `CodexUsageMonitor/Scripts/build-app.sh`: exit 0; Developer ID signed; `codesign --verify --deep --strict` passed. Packaging emitted the existing dyld AVFCore/MediaToolbox missing-symbol diagnostics; they did not prevent successful asset compilation or signing.
- Signed-app inspection: dark Claude menu showed usable quota, source and original update time with the footer reachable. Exercised ordinary Refresh by shortcut and the Settings button, and explicit Reconnect using the existing grant. A sanitized 15-minute securityd/SecurityAgent log query around launch/ordinary refresh reported zero displayed prompt events. The signed `--claude-live-read-once` probe exited 0 with live OAuth and zero warnings.
- At the default 680 × 560-point Settings content size (680 × 588 including title bar), directly inspected Claude in Light and Dark with Context Rail hidden and visible. Rail-visible window measured 891 points wide; the central page and card gutters stayed fixed. Scrolling reached the Source and Force a reading sections; descriptions wrapped and controls remained inside cards. Shortened an oversized reconnect disclosure following the first visual pass. Restored the original System appearance and hidden rail afterward.
- Explicit signed-app `/usage` recovery succeeded using existing consent. Settings displayed `Claude Code CLI · Last updated just now`; a sanitized cache inspection confirmed source `cli` and quota windows present. No automatic refresh invoked the CLI.
- Local screenshots: `/tmp/claude-passive-menu.png`, `/tmp/claude-passive-settings-dark-final.png`, `/tmp/claude-passive-settings-source.png`, `/tmp/claude-passive-settings-light.png`, `/tmp/claude-passive-settings-light-hidden.png`. These are local acceptance artifacts, not public repository assets.
- Remaining native acceptance: first-time setup with an actually denied/cancelled Keychain grant, forced `/usage` failure, Disconnect while a real request is in flight, VoiceOver, full keyboard navigation, and menu under macOS Light. Existing working provider credentials were not altered to manufacture failures; Settings Light is not evidence for the system-owned menu in Light. Those native states are not claimed as verified. No shared Settings geometry was changed.
- One final checkout app instance remains running as the user's requested latest monitor; no separate audit instance or CLI probe remains. No production Keychain item, global search list, installation, or release artifact was changed. Credential-update and sleep/wake durability remain separate diagnosis work.

## September 22 diagnosis-only findings — fixes pending

- Fresh passive readings never reach Claude threshold evaluation: the call-site
  guard accepts only `.live`, while passive capture uses `.passiveSnapshot`.
- Manual `/usage` parses percentages but writes nil reset times, even though the
  observed CLI output included both resets. The threshold evaluator skips
  windows without a reset timestamp. This separately blocks CLI quota alerts.
- The header maps passive delivery to Cached, and its refreshing input excludes
  the manual CLI progress flag.
- Existing evaluator tests (8) and CLI parser tests (9) passed, exit 0. The
  evaluator suite explicitly confirms no-reset suppression. These are boundary
  checks, not a regression test of the passive call-site guard or proof of native
  notification delivery. No fixes or forced notifications were performed.
- Keychain ACL evidence and the reconnect observation remain in the separate
  [diagnosis record](../../development/claude-keychain-grant-durability.md#september-22-silent-access-diagnosis).
- Model-follow-up spelling from the user is **Astra and Claude Fable 5 and 5.1**;
  exact identifiers remain unconfirmed and model implementation is out of scope.
