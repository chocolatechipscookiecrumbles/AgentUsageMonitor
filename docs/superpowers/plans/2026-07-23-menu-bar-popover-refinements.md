# Menu-bar popover refinements (2026-07-23)

Follow-up refinements to the multi-provider popover shipped by
[the Figma port](2026-07-22-menu-bar-popover-figma-port.md), from direct user
direction. Confirmed before implementation. The branch's standing waiver still
applies: GUI/keyboard/VoiceOver/Light-Dark verification is **unobserved**,
never passed.

## Confirmed decisions

- **A — Claude source label:** headers are made identical across tabs; the
  Claude source (`Claude OAuth` etc.) moves out of the header into a compact
  caption in the Claude content. This **supersedes** the Task 5a decision that
  put provenance in the header subtitle — provenance stays visible on the menu,
  just in the content rather than the header.
- **B — Denied-notification recovery:** keep a slim strip (Option 2), and show
  it on **both** the Codex and Claude tabs whenever notifications are not
  granted (`notificationAuthorizationState == .denied`). The quota-alerts
  *toggle* is removed from the popover (it still lives in Settings); the footer
  **Notification Settings** row is unaffected.

## Tasks

1. **Standard header freshness format — both tabs.** In
   `MenuProviderHeaderPresentation`, the available-state subtitle becomes
   `Updated: <time> · <relative>` (absolute `time` via
   `.formatted(date:.omitted, time:.standard)`, relative via
   `RelativeTimeText.text`). Codex uses `collectedAt`; Claude uses
   `snapshot.capturedAt`. `Refreshing…` / `Usage unavailable` states unchanged.

2. **Header title → provider name.** `"Codex Usage Monitor"` / `"Claude Usage
   Monitor"` → `"Codex"` / `"Claude"`. Footer **Quit Codex Usage Monitor** keeps
   the app name.

3. **Claude source caption in content.** In `ClaudeMenuContent`, add a compact
   secondary-text caption (`Source: <sourceLabel>`) beneath the window card,
   near the shared-pool caveat. Removed from the header.

4. **Codex icon fills its tile.** In `ProviderIconTile` (popover-only; not used
   elsewhere), Codex artwork fills the full tile (`providerIconTileSize`) and is
   clipped to the tile's rounded corners; Claude keeps the padded
   `providerIconArtworkSize`. `AgentSettingsIcon` (shared with Settings) is left
   unchanged.

5. **Remove the Codex quota-alerts toggle; shared denied strip.** Drop
   `CodexQuotaAlertsCard` from `CodexMenuContent` and delete the file. Add a
   provider-agnostic `NotificationPermissionStrip` (warning + **Open System
   Notification Settings** → `viewModel.openNotificationSettings`) rendered by
   **both** `CodexMenuContent` and `ClaudeMenuContent` when
   `notificationAuthorizationState == .denied`. `.notDetermined` deliberately
   does not show it (the toggle now lives only in Settings, so nagging before
   the OS has been asked would be wrong).

6. **Credit balance → 4 significant figures in the popover only.** In
   `CodexMenuPresentation`, format `Credits.balance` to 4 significant figures
   (parse `Double`, `.formatted(.number.precision(.significantDigits(1...4)))`;
   fall back to the raw string if non-numeric). Settings keeps full precision
   via `presentation.creditBalance`.

7. **Refresh Now keeps the popover open — IMPLEMENTED IN SOURCE 2026-07-24.**
   The footer **Refresh Now** no longer dismisses (unlike the other footer
   commands) and shows the in-place `Refreshing…` header/footer state. The
   production root also handles Escape dismissal. Signed-app visual and
   keyboard observation remain open.

8. **Add-a-provider-tab template.** New doc
   `docs/design/menu-bar-popover/ADDING-A-PROVIDER-TAB.md` derived from the
   Codex/Claude tabs: required file set, header/catalog/persistence wiring, and
   the passivity/no-furniture rules.

## Verification

`swift build`, full suite, `git diff --check`, ad-hoc app-bundle build. No new
feature-presence tests (branch policy); the credit-formatting helper is the one
piece of pure logic and may take a narrow test if it is extracted testably.
Visual states remain waived/unobserved.

## Round 2 — visual fixes (2026-07-23, confirmed)

From direct screenshot feedback. Decisions confirmed: usage-color change applies
to the **popover only** (Settings keeps its accepted provider tint); the shell
stays **rounded but one piece** (transparent host window), with squaring as the
fallback.

1. **Single rounded piece (corner artifacts; not accepted).** `MenuPopoverWindowConfigurator`
   (new) makes the `MenuBarExtra(.window)` host window transparent
   (`isOpaque = false`, clear background, `hasShadow = true`) so only the rounded
   `MenuPopoverChrome` shows and the window server draws a matching rounded
   shadow. The chrome's own SwiftUI `.shadow` is removed to avoid a mismatched
   double shadow. The user reports that the artifact remains, so this is not a
   completed fix. Further production changes are deferred until signed-app
   first-frame/window-layer instrumentation and prototype comparison can identify
   the real corner owner.
2. **Timestamp drops seconds** — `updatedText` uses `time: .shortened`.
3. **Tab hit target** — the full equal-width column was already clickable; raised
   `tabStripHeight` `36 → 44` and added a full-column hover fill.
4. **Footer flush** — removed the action rows' vertical padding so Refresh Now
   and Quit sit at the edges.
5. **Usage color threshold** — `MenuPopoverTheme.quotaLevel` boundary is now
   `remaining < 10` → danger (i.e. `used > 90`), matching used `< 75` / `75…90` /
   `> 90` → green / yellow / red. Popover bars + numerals only; the color already
   tracks usage, so reversed used/remaining wording is unaffected.

These are GUI changes under the branch's waiver — build/tests confirm they
compile and don't regress the suite. Corner/shadow, Light/Dark, keyboard,
VoiceOver, and rendered-height checks remain unobserved; the corner artifact is
still user-observed and explicitly deferred rather than claimed fixed.
