# ADR 0004: Content-fitted menu panel

- Status: Accepted (2026-09-30). The panel is the default menu; `--menu-host=legacy` or the `MenuHostLegacy` default restores the stable-host `MenuBarExtra` menu.
- Date: 2026-09-29
- Supersedes: [ADR 0003](0003-own-menu-presentation-geometry.md)

## Context

The production menu avoids the provider-switch artifact by keeping `MenuBarExtra`'s
host window at a stable, screen-capped 860 points while the visible shell fits its
content. The user confirmed that switching works, but the transparent host still
reads as a leftover dropdown: an outlined, shadowed region continues below the menu,
and clicks in it do not reach the app underneath.

Two mechanisms caused the rejected ADR 0003 trials to recreate the artifact
([diagnosis](../development/provider-switch-diagnostic-results.md#trial-rejection-and-diagnosis--2026-09-28)):

1. The hosted root was not anchored to the top. Whenever the window height and the
   shell height differed, SwiftUI centered the shell, moving the tabs and header by
   half the difference.
2. The window was resized after measuring, a run-loop turn after the content
   commit, in both directions. Growth therefore always had at least one frame in
   which the window was smaller than the new content.

SwiftUI's layer commit and a window-server frame change follow separate paths;
public API cannot prove that both land in the same displayed frame.

## Decision

Host the menu in an app-owned, non-activating `NSPanel` under an owned
`NSStatusItem`, and enforce these invariants:

- **I1 Top anchor.** The hosted root is anchored to the top, so a stale window
  height never moves the tabs or header.
- **I2 Envelope.** The window is never smaller than the committed content. Every
  content change (tab selection, refresh, settings or enrollment change) goes
  through one pipeline: build the next snapshot, pre-measure it offscreen, grow the
  window if needed, then publish it to SwiftUI, in one main-thread turn.
- **I3 Fit at rest.** After the live surface settles, the window shrinks to the
  shell height on the next run-loop turn.
- **I4 No stale shrink.** A shrink proposed before a newer grow is dropped.
- **I5 No private host.** The panel is clear and non-opaque; the shadow is
  invalidated after each frame write.
- **I6 Semantic events only.** No timer, `TimelineView` or per-second
  invalidation drives geometry.

The SwiftUI surface observes only controller-published snapshots, never the view
model, so no content reaches the screen before it has been measured. A pre-measured
height that is smaller than the settled height grows the window late and logs a
debug fault; it is a measurement bug to fix, not a tolerance.

User decisions: non-activating panel; about a 0.1 s opacity-only fade; outside
clicks close the menu and pass through; focus + Return keyboard selection only;
Settings opens through the application menu's ⌘, command; the stable
`MenuBarExtra` host remains as a kill switch after promotion.

## Alternatives rejected

- **Keep the fixed transparent host.** Accepted today and kept as the kill switch,
  but it retains the outline and the click-swallowing tail.
- **Resize `MenuBarExtra` to content.** Its private host resize is the July root
  cause.
- **Resize after measuring** (ADR 0003 trials). Recreated the artifact.
- **`NSPopover`.** Rejected chrome, and the system owns its resize.
- **Grow to the screen cap before every change.** Simpler, but rejected in favor
  of pre-measuring.
- **Commit the frame and the content in the same frame.** Not provable with
  public API; the ordering guarantee does not need it.

## Consequences

- The app gives up `MenuBarExtra` conveniences: status-item overflow handling,
  the scene-backed `openSettings` action and system dismissal. The panel
  reimplements them and they need signed-app acceptance.
- A new status item may take a different position in the menu bar.
- Correctness still depends on AppKit's resize compositing for a borderless,
  non-opaque window. The kill switch covers a future macOS regression.
- Acceptance is a user-operated 60 fps recording; automated tests cover only the
  anchor and envelope invariants.
