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

Status: **Queued.** The user reported this path on 2026-07-17. Runtime reproduction was not attempted because it would require disrupting or substituting the user's active Codex session; the code-path evidence below explains the missing automatic transition. The dedicated [External Codex Login Detection Implementation Plan](../superpowers/plans/2026-07-17-external-codex-login-detection.md) defines the controller-owned 30-second and activation-triggered implementation boundary.

Problem

When Codex Usage Monitor is already showing its disconnected/sign-in stage, a user may ignore the app's Browser and CLI actions and run `codex login` independently in Terminal. Codex then owns a valid Provider Session, but the running app can remain on the disconnected stage instead of detecting the new session and returning to quota display automatically.

Current code-path evidence

* `CodexConnectionController.start()` performs one status read at application startup.
* The two-second `codex login status` watcher starts only inside `signInWithCLI()`, after the app opens Terminal itself.
* `QuotaViewModel` requests a silent connection recheck only after a quota refresh publishes `.failed`. If the independent login makes the next quota refresh succeed, that success does not recheck or reconcile the still-disconnected connection state.
* There is no disconnected-state poll, application-activation recheck, Provider Session change observer, or menu-presentation hook that fills this gap.

Desired behavior

`CodexConnectionController` should own bounded detection of an externally changed Provider Session while its state is disconnected. The implementation plan should evaluate an immediate application-activation recheck plus a conservative, cancellable disconnected-state interval as complementary triggers. It must not make native-menu rendering own the check or create a second quota scheduler.

When a read-only `account/read` first confirms the external login, the controller should publish `.connected` and invoke the existing authentication-refresh callback exactly once. Detection must stop or idle after connection, coalesce overlapping status reads, preserve an explicit `CODEX_HOME`, and retain the existing privacy boundary: never read `auth.json`, tokens, email, or raw provider output.

Acceptance

* Start the signed app against an isolated disconnected Codex home and do not click either app sign-in action.
* Complete `codex login` independently in Terminal using that same Codex home.
* The running app detects the Provider Session within a documented bounded interval, replaces the disconnected stage with connected quota content, and performs exactly one authentication refresh without a relaunch or manual **Check again**.
* Opening and closing the native menu does not start duplicate watchers, status processes, or refreshes.
* Failed status reads remain retryable and do not trap the UI in `.checking` or `.signingIn`.
* The existing in-app Browser and CLI flows, external-logout detection, sleep/wake behavior, custom `CODEX_HOME`, and process teardown remain intact.
