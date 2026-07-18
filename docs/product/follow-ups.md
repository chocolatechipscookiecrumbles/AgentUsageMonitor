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
