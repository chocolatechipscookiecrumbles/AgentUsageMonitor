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

7. **Refresh Now keeps the popover open — DOCUMENTED, DEFERRED.** The footer
   **Refresh Now** should *not* dismiss (unlike the other footer commands); it
   should show the in-place `Refreshing…` header/footer state. Recorded in the
   SPEC and here; **not implemented** in this pass.

8. **Add-a-provider-tab template.** New doc
   `docs/design/menu-bar-popover/ADDING-A-PROVIDER-TAB.md` derived from the
   Codex/Claude tabs: required file set, header/catalog/persistence wiring, and
   the passivity/no-furniture rules.

## Verification

`swift build`, full suite, `git diff --check`, ad-hoc app-bundle build. No new
feature-presence tests (branch policy); the credit-formatting helper is the one
piece of pure logic and may take a narrow test if it is extracted testably.
Visual states remain waived/unobserved.
