# Product Follow-ups

These source notes are indexed and status-tracked in the centralized [Product Planning Board](planning-board.md). Keep detailed problem statements here and update board status/next actions when an item changes.

## 1. Network-aware refresh scheduling and diagnostics

Problem

The collector currently treats refresh failures largely in isolation. It cannot distinguish between:

* temporary internet loss
* Wi-Fi changes
* VPN reconnects
* captive portals
* provider outages
* authentication failures
* local DNS problems

As a result, refresh failures appear identical and users have little guidance about why collection stopped.

Desired behavior

Introduce a network-awareness layer that continuously observes network reachability and path changes.

The app should:

* detect network connectivity changes
* detect interface changes (Wi-Fi, Ethernet, VPN)
* detect transitions between offline and online
* detect network restoration after temporary outages

Network status should become part of refresh diagnostics rather than only reporting generic failures.

Possible diagnostic states include:

* Offline
* Network changing
* Internet unavailable
* DNS unavailable
* Provider unreachable
* Authentication failed
* CLI unavailable
* Unknown

These should remain evidence-based rather than speculative.

Refresh behavior

When connectivity returns:

* immediately schedule a refresh
* cancel waiting for the normal refresh interval
* avoid requiring the user to press Refresh manually

Normal scheduling resumes afterward.

Acceptance

* refresh immediately after network restoration
* no duplicate refreshes
* diagnostics reflect actual observed network state
* existing refresh scheduler remains authoritative

⸻

## 2. Automatic recovery from interrupted sign-in flow

**Status:** **Deferred.** The observed cancelled-Browser-to-external-CLI-login gap now has a dedicated [interrupted sign-in recovery plan](../superpowers/plans/2026-07-17-interrupted-signin-recovery.md). No source change has started; resume only on explicit direction.

Problem

If Browser Sign-In or CLI Sign-In fails during the intermediate connection state, the UI can become stuck on an in-progress/disconnected screen.

The user currently has no recovery path except quitting and relaunching the application.

Desired behavior

The connection workflow should always recover back to a usable state.

Recovery options may include:

* timeout
* failed authentication detection
* cancelled browser session
* failed CLI invocation
* connection watchdog

Once recovery conditions are met, automatically return to the normal disconnected state.

Requirements

The user should never become trapped inside an intermediate connection screen.

The original sign-in options should become available again automatically.

Provide clear status such as:

* Sign in cancelled
* Browser closed
* Authentication timed out
* Connection failed

without exposing implementation details.

Acceptance

* no restart required
* repeated sign-in attempts work normally
* recovery is automatic whenever possible

⸻

## 3. Menu popover layout regression

Problem

The Reset text overlaps the Quota Alerts control inside the menu popover.

Desired behavior

Rework spacing so:

* controls never overlap
* text truncation follows native macOS behavior
* Dynamic Type and localization remain supported
* narrow menu widths remain readable

Acceptance

No overlapping controls under supported window sizes.

Verification evidence — 2026-07-18

The reported copy was `Resets: Jul 25, 2026 at 17:24`. It is not currently reproducible in the native menu, so no layout correction is claimed or implemented. Keep this item open for signed-app verification after future menu changes: inspect long reset copy beside **Quota alerts** at narrow supported widths, with localized/Dynamic Type text, Light/Dark, scrolling, pointer/keyboard/VoiceOver navigation, and command activation.

⸻

## 4. Finish System appearance transition implementation

Status: **Closed on 2026-07-16.** The live Settings presentation owner fixed the mixed Light/System/Dark hierarchy and completed signed-app acceptance across both host appearances and live macOS switching. Manufactured conditional states remain a verification item, not an open appearance implementation. See the [accepted appearance plan](../superpowers/plans/2026-07-15-settings-system-appearance-transition.md).

Problem

The previously documented appearance regression still exists.

Switching between:

Dark → System

can produce inconsistent rendering where:

* dividers
* outlines
* grouped card borders
* backgrounds

remain in the previous appearance while other regions correctly adopt System.

Desired behavior

The entire Settings window should transition as one visual hierarchy.

Every region should inherit the same effective appearance.

This includes:

* title bar
* sidebar
* page
* context rail
* grouped cards
* borders
* dividers
* controls

No region should retain stale appearance values.

Acceptance

Exercise:

* Light → System
* Dark → System
* System → Light
* System → Dark
* live macOS appearance changes

No mixed appearance should remain.

⸻

## 5. Simplify General Settings context rail

**Status:** **Queued.** The [Figma Settings Design Completion plan](../superpowers/plans/2026-07-17-figma-settings-design-completion.md) implemented the native rail geometry, switches, General cleanup, Menu Bar Icon **Style**/**Show** plus Settings-window System/Light/Dark **Appearance** segments, and Diagnostics ownership of Name, Version, and Build while preserving the existing theme and Settings behavior. Fresh package and signed-bundle checks pass; this follow-up must not advance to Verification until direct signed-app acceptance covers both rail states, the new segmented control, Diagnostics relocation, and conditional content.

Problem

The current General context rail duplicates information already visible elsewhere.

Specifically:

* “Current Label” wastes vertical space
* the Menu Bar Preview is unnecessarily constrained
* there are two different menu bar previews
* “Current Scope” no longer provides useful information

Desired behavior

Context Rail

Replace the current preview with a larger menu-bar preview occupying the full available card width.

Remove:

* Current Label text

Allow the menu-bar representation itself to become the primary preview.

General page

Remove the duplicate Preview section inside Menu Bar settings.

The context rail becomes the single authoritative preview.

Also remove:

Current Scope

since Codex-only support is already communicated elsewhere.

Acceptance

* one menu bar preview
* larger preview
* less duplicated information
* cleaner General page

⸻

## 6. Dedicated Permissions Settings destination

Problem

Permission-related controls are currently scattered across the application.

Users often do not know:

* which permissions are missing
* why features are unavailable
* how to grant permissions

Desired behavior

Create a dedicated top-level Settings destination:

Permissions

This page becomes the central location for all macOS permission management.

Potential sections include:

Notifications

* current authorization status
* request permission
* open Notification Settings

Accessibility

* granted / missing
* open Accessibility settings

Login Items

* launch at login status
* open Login Items

Automation

Future support if needed.

Screen Recording

Future support if needed.

Full Disk Access

Only if future functionality requires it.

Design

Each permission should include:

* current status
* explanation of why it is needed
* one-click button to open the correct macOS Settings page

The page should never attempt to bypass macOS permission workflows.

Acceptance

* all permissions visible in one place
* users never need to hunt through General or Notifications
* each permission links directly to the appropriate macOS Settings pane
* unavailable permissions clearly explain why functionality is limited

⸻

## 7. Future enhancement: richer refresh failure explanation

Beyond simple failure states, consider adding a structured “Why didn’t my refresh succeed?” section.

Possible observable causes include:

* No internet connection
* VPN disconnected
* DNS resolution failed
* Codex servers unreachable
* Authentication expired
* CLI not installed
* Refresh already in progress
* Provider rate limiting
* Temporary provider outage

Each diagnosis should be accompanied by:

* evidence used to reach the conclusion
* suggested user action (if applicable)
* confidence level where multiple explanations are possible

This should remain evidence-driven rather than attempting to guess unsupported failure causes.

⸻

## 8. Detect an external Codex login while disconnected

Status: **Verification.** The controller-owned implementation is complete. Isolated user acceptance on 2026-07-17 observed independent `codex login` reconnect within the 30-second bound, a prompt activation-triggered reconnect, one persisted authentication refresh, and a repeated-activation check. Negative-path and teardown checks remain open in the dedicated [External Codex Login Detection Implementation Plan](../superpowers/plans/2026-07-17-external-codex-login-detection.md).

Problem

When Codex Usage Monitor is already showing its disconnected/sign-in stage, a user may ignore the app's Browser and CLI actions and run `codex login` independently in Terminal. Codex then owns a valid Provider Session, but the running app can remain on the disconnected stage instead of detecting the new session and returning to quota display automatically.

Implementation evidence

* `CodexConnectionController` now starts one cancellable 30-second status watcher only after it enters `.disconnected`, and stops it after any non-disconnected state.
* While disconnected, the controller also owns one application-activation observer. It silently calls the existing read-only `account/read` status reader and does not replace the disconnected menu with `.checking`.
* The existing single `connectionTask` guard coalesces startup, manual, refresh-failure, interval, activation, and sign-in checks. A first non-startup transition from disconnected to connected invokes the existing authentication-refresh callback once.
* The menu remains a consumer of published state; it owns no watcher, status process, or quota scheduler. The implementation reads no credential file, token, email, or raw provider output.

Implemented behavior

`CodexConnectionController` owns bounded detection of an externally changed Provider Session while its state is disconnected. It combines an immediate application-activation recheck with a conservative, cancellable 30-second disconnected-state interval. Native-menu rendering does not own the check and no second quota scheduler is created.

When a read-only `account/read` first confirms the external login, the controller publishes `.connected` and invokes the existing authentication-refresh callback once. Detection stops after connection, overlapping status reads coalesce, explicit `CODEX_HOME` remains preserved, and the existing privacy boundary remains: never read `auth.json`, tokens, email, or raw provider output.

Acceptance

* **Observed:** a signed app ran against two fresh isolated disconnected Codex homes without either in-app sign-in action.
* **Observed:** the user completed `codex login` independently in Terminal with each matching home.
* **Observed:** the interval route changed the disconnected stage to connected roughly five seconds after login (within the 30-second bound); the activation route connected promptly in roughly two to three seconds. The time remaining to the interval tick was not measured.
* **Observed:** a before/after read of the sanitized app-owned diagnostics record showed exactly one new `authentication` refresh (6 to 7) with a confirmed outcome. The Diagnostics Settings screen does not expose reasons, so this was not a visible-Diagnostics check.
* **Observed:** the user reported that rapid repeated activation after external login passed. The deterministic controller regression separately proves that a second activation does not invoke the callback again.
* **Observed limitation:** after an in-app Browser sign-in was cancelled, the controller entered `.failed`; an independent external CLI login from that state was not detected. The watcher is intentionally scoped to `.disconnected`, and this is evidence for Product Follow-up 2 rather than accepted interrupted-sign-in recovery.
* **Not run:** failed-read retryability, custom-home behavior beyond the observed independent-login paths, external logout, sleep/wake, controller teardown, and audit cleanup.

⸻

## 9. Claude refresh can recover usage without recovering plan identity

**Status:** **Needs plan.** This is a user-observed intermittent defect recorded on 2026-07-30. No implementation change has started, and the trigger for the initial missing Keychain/Claude values has not yet been isolated.

Problem

At certain times, an ordinary Claude refresh does not have the Keychain credential or Claude values available for the app to read. The ordinary refresh is intentionally non-interactive, so it does not show a Keychain access prompt. The app instead reports that the Claude connection **Needs attention**.

The explicit, user-authorized Claude CLI `/usage` check can then recover current usage windows. That result does not include the account's plan identity, however, so the app enters a partially recovered state:

* quota usage is available
* **Connection** shows a status and the **Connected account** action
* the **Plan** row is absent

A later ordinary refresh can restore the plan name. Requiring that extra refresh leaves connection identity and usage out of sync and is not accepted recovery behavior.

Reproduction boundary

1. Reach the intermittent state in which an ordinary Claude refresh cannot read the Keychain credential or Claude values.
2. Confirm the refresh does not raise a Keychain prompt and the app shows **Needs attention**.
3. In Claude Settings, run the explicit **Force a reading** CLI check, which uses Claude's `/usage` result.
4. Confirm usage appears, while **Connection** shows status and **Connected account** but omits **Plan**.
5. Run another ordinary refresh and observe that the plan may return.

Known data boundary

The Claude OAuth/Keychain path can supply the plan hint from the credential. The CLI `/usage` snapshot supplies quota windows but currently carries no plan hint. The missing plan after the CLI check is therefore a real source-reconciliation gap, not evidence that the account has no plan.

Required outcome

Plan the fix around one coherent Claude state transition. A successful recovery must not leave live usage, connection status, connected-account actions, and plan identity contradicting one another.

The plan must:

* preserve the rule that scheduled and ordinary refreshes do not unexpectedly open a Keychain prompt, unless a separately approved interaction design changes that policy
* provide an explicit, understandable recovery path when credential access requires user interaction
* define how a CLI usage result that lacks plan identity combines with the last confirmed account identity
* avoid presenting an absent CLI plan field as proof that the plan is unavailable
* avoid requiring a second refresh to make Connection internally consistent
* keep the existing single-owner source hierarchy and avoid a parallel connection or refresh state

Acceptance

* reproduce the initial missing-Keychain/missing-Claude-values state deterministically, or capture enough diagnostics to identify its trigger
* an ordinary refresh remains non-prompting
* the user can recover through one clear action
* after recovery, usage, status, connected-account actions, and Plan agree
* the CLI-only path either retains a valid last-confirmed plan identity with accurate provenance or clearly represents the identity as unresolved without a contradictory connected state
* another ordinary refresh is not required to restore the Plan row
* relaunch, cached data, expired credential, denied Keychain access, CLI-only success, and later OAuth recovery are covered explicitly

⸻

## 10. Consolidate the Claude usage bridge into the app executable

**Status:** **Needs plan.** The 0.0.1 implementation works and was signed,
notarized, published, and verified, but its packaging boundary is more complex than
the product needs.

Problem

`ClaudeUsageBridge` is not a passive resource. It is a separate native executable
binary nested in the app bundle. `build-app.sh` builds and signs that helper first,
then signs the containing app. The release verifier and notarization boundary must
therefore account for two executable code objects. This is operationally correct,
but it increases build, signing, verification, update, and failure surface.

Required outcome

Ship one executable binary in the app bundle. The main Agent Monitor executable
should expose a dedicated non-UI bridge mode that can receive Claude Code's
status-line JSON on stdin, extract the existing allowlisted rate-limit fields, write
the same atomic owner-only snapshot, and exit without launching the menu-bar app.
The release build should require one app signing operation rather than a separate
nested-helper signing step followed by app signing.

The plan must compare at least:

* invoking the executable inside the installed app bundle with a bridge-mode
  argument, including what happens when the app is moved or replaced
* copying the already signed main executable to the deterministic app-owned
  Application Support path, including update and code-signature behavior
* eliminating passive status-line capture if neither single-binary route can meet
  path stability, privacy, and reliability requirements

Constraints

* preserve the current stdin/stdout/exit contract expected by Claude Code
* do not initialize SwiftUI, `NSApplication`, menu state, refresh scheduling,
  Keychain access, or network collection in bridge mode
* retain field-scoped extraction: never persist prompts, responses, paths, model
  metadata, or other status-line fields
* retain atomic writes and owner-only directory/file permissions
* migrate existing `~/.claude/settings.json` status-line commands without
  clobbering unrelated user configuration or leaving a broken helper path
* define rollback and compatibility for existing 0.0.1 installations
* keep `ClaudeUsageBridgeCore` reusable and directly testable even if the separate
  executable target is removed

Acceptance

* the shipped app bundle contains one executable Mach-O binary
* `build-app.sh` no longer builds, copies, or separately signs a nested bridge
* the bundle, signing, and notarization verifiers expect one executable
* passive capture produces the same sanitized snapshot from the same fixtures
* invoking bridge mode cannot open UI or start the normal app lifecycle
* a real Claude Code status-line invocation survives app upgrade, move, relaunch,
  and rollback without manual repair

⸻

## 11. Codex Token Monitor can fail to read local usage

**Status:** **Needs diagnosis.** Observed in the published 0.0.1 release. No cause
or workaround is confirmed.

Problem

Codex has been used locally, but its Token Monitor can remain without local token
usage instead of publishing observed requests. Provider quota and local token
activity are separate paths, so a working quota connection does not prove that
transcript discovery and reconciliation work.

Unknown boundary

The current report does not distinguish among an undiscovered/custom Codex home,
file permissions, transcript-schema drift, unsafe-file rejection, incremental
reader/cache state, file-event delivery, or reconciliation. These are investigation
targets, not root-cause claims. Do not ask for or export raw prompts or responses to
diagnose the failure.

Required outcome

Reproduce the released failure with sanitized diagnostics, identify the exact
discovery/read/reconciliation boundary, and make the Token Monitor either publish
the correct locally observed totals or name an evidence-supported unavailable
reason and recovery action.

Acceptance

* test default and explicit `CODEX_HOME`, missing roots, unreadable roots, current
  record schemas, app launch, file events, cache rebuild, disable/re-enable, and
  relaunch
* retain field-scoped decoding and never persist or export record content, paths,
  session identifiers, prompts, or responses
* a valid empty day remains distinguishable from failed discovery or reading
* the released failure gets the smallest deterministic regression once reproduced

⸻

## 12. Claude setup is not a dependable first-run flow

**Status:** **Needs diagnosis and interaction plan.** The user reported the
published setup as problematic, but the exact failed step has not yet been captured
well enough to claim a root cause.

Problem

Claude setup spans existing Claude Code credentials, a possible Keychain prompt,
passive status-line capture, cached state, and the explicitly consented CLI
`/usage` recovery. In the released experience these boundaries can require extra
or unclear recovery actions rather than one understandable setup sequence.

Required outcome

Instrument and observe the first-run transitions before redesigning them. The app
must clearly distinguish:

* existing Claude Code credentials available without interaction
* credential access requiring an explicit user action and possible Keychain prompt
* passive status-line capture installed, absent, stale, or conflicting
* CLI-only usage recovery that does not prove account/plan identity
* setup failure with a safe, specific retry path

Acceptance

* one guided path reaches a coherent connected/usable state or names the exact
  blocker without contradictory status
* ordinary background refresh remains non-prompting
* existing custom `~/.claude/settings.json` configuration is never overwritten
* cancel, deny, retry, relaunch, stale snapshot, and later credential recovery are
  explicit
* Follow-up 9's usage/plan reconciliation and Follow-up 10's executable packaging
  remain separate ownership boundaries rather than being hidden inside setup copy

⸻

## 13. First launch should require explicit connection for both providers

**Status:** **Needs plan.** Requested connection-policy hardening after 0.0.1.

Problem

The 0.0.1 app can infer provider availability from existing CLI state before the
user has explicitly connected that provider inside the app. That makes the consent
boundary unclear, especially for Claude, where an intentional connection action is
the appropriate place to explain and authorize a possible cross-app Keychain
prompt.

Required outcome

On a fresh app installation, Codex and Claude both begin in app-local
**Disconnected** states and require separate, explicit connection actions before
quota collection starts. Connecting one provider must not connect or alter the
other. The flow may perform non-interactive capability checks needed to explain the
next action, but it must not silently adopt an existing CLI session as an
app-level connection.

Acceptance

* test fresh app state with both CLIs signed in, only Codex signed in, only Claude
  signed in, neither signed in, missing CLIs, denied interaction, and custom homes;
  both app-level providers still begin disconnected
* Codex and Claude expose independent Connect actions with provider-specific
  disclosure and recovery
* launch, scheduled refresh, wake refresh, and passive discovery never trigger a
  Keychain prompt or silently convert a provider to connected
* connecting one provider does not connect, sign in, sign out, or otherwise mutate
  the other provider
* reconnect after an app-local disconnect remains explicit, while upgrades preserve
  a previously established app-level connection unless a migration plan says
  otherwise
* connection state and Token Monitor collection remain separate; whether local
  activity should be visible before quota connection is an explicit product choice,
  not an accidental authentication side effect
