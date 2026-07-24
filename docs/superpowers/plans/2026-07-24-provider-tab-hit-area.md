# Provider Tab Hit-Area Enlargement Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking. This is a bounded, source-level hit-testing correction, not an evidence-first diagnosis. Implement it directly; do not attach the corner-artifact or provider-switch diagnosis instrumentation to it.

**Goal:** Make the full visual tab region clickable for both provider selectors — the menu-bar popover strip and the Settings Agents strip — so the pointer target matches the drawn tab instead of only the text (and icon).

**Architecture:** Both selectors are custom `Button`-per-tab `HStack`s with `.buttonStyle(.plain)`. A plain button's hit region is defined by its **label's** content shape. The fix is to make each button's label own the full equal-width, full-height tab rectangle and declare an explicit `contentShape`, so the button — not a surrounding layout frame — owns the whole region.

**Tech Stack:** Swift 6.2, SwiftUI for macOS 14+, Swift Package Manager.

## Global Constraints

- Work on `feature/multiprovider-menubar-popover`; do not push without explicit approval.
- Change only hit-testing/layout ownership. Do not change the selection model, tab titles, colors, indicator/underline art, divider art, or the surrounding strip geometry.
- Keep the menu popover 340 points wide and non-scrolling; keep the Settings strip's existing `ViewThatFits` fitting/overflow behavior.
- Preserve the resolved provider-switch geometry fix (the shared 288-point menu content floor and the Settings viewport-filling envelope). This change must not reintroduce a host resize on selection.
- Keep existing accessibility traits/labels/values; the enlarged target must remain a single selectable element per tab.
- This is a private-compositing hit-testing change. Automated state tests cannot prove pointer behavior; signed-app pointer/keyboard verification is the acceptance gate and, per the branch waiver, is recorded as unobserved unless the user operates it.

## Current Source State

### Menu — `Menu/MenuProviderTabStrip.swift`

- Each tab is a `Button` whose **label is only `Text(provider.tabTitle)`**.
- `.frame(maxWidth: .infinity, maxHeight: .infinity)` and `.contentShape(.rect)` are applied **outside** the `Button`, after `.buttonStyle(.plain)`. They expand the layout footprint and give the *outer* view a shape, but they do **not** feed the plain button's gesture, so only the text glyphs are tappable.
- Strip height is already `MenuPopoverTheme.tabStripHeight` = 44 points.

### Settings — `Settings/AgentSettingsTabStrip.swift`

- Each tab's label is an icon + text `HStack` with a fixed `.frame(width: 132, height: 52)` **inside** the label, plus a bottom underline overlay.
- The label has **no `contentShape`**, so a plain button hit-tests the non-transparent label content (icon + text) rather than the full 132×52 tab; the gaps around the glyphs are dead.
- Header height is already `SettingsLayoutMetrics.pageHeaderHeight` = 52 points.

Both heights already satisfy a comfortable target; only the **shape ownership** is wrong.

## File Map

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderTabStrip.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsTabStrip.swift`
- Modify: `docs/design/menu-bar-popover/SPEC.md` — record the tab hit-target contract.
- Modify: `docs/product/planning-board.md` — move the hit-area item out of Deferred.
- Modify: `AGENTS.md` — note the guardrail is now satisfied in both strips.

---

### Task 1: Give the menu popover tab button's label the full column

**File:** `Menu/MenuProviderTabStrip.swift`

- [ ] **Step 1:** Move the fill frame and content shape **inside** the `Button` label. The label becomes `Text(...)` carrying `.font`, `.foregroundStyle`, `.frame(maxWidth: .infinity, maxHeight: .infinity)`, then `.contentShape(.rect)`. The label's `maxWidth: .infinity` also lets each button divide the strip width equally, so the outer equal-width frame is no longer needed.
- [ ] **Step 2:** Keep the hover `background`, the bottom accent `overlay`, `.onHover`, and `.accessibilityAddTraits` on the button so the visible hover fill and indicator still cover the whole column and match the now-identical hit region.
- [ ] **Step 3:** Confirm the strip still pins to `tabStripHeight` (44) and the `ProviderSwitchTrace.record(.menuPopover, .buttonAction, …)` call is preserved inside the action.

### Task 2: Declare the Settings tab label's full rectangle as its hit shape

**File:** `Settings/AgentSettingsTabStrip.swift`

- [ ] **Step 1:** Add `.contentShape(.rect)` to the label, applied after the fixed `.frame(width:height:)` and the underline `.overlay`, so the full `agentHeaderTabWidth` × `pageHeaderHeight` rectangle is hit-testable. Do not change the frame size, underline, divider, `ViewThatFits`, or `onMoveCommand` keyboard handling.
- [ ] **Step 2:** Confirm the inter-tab divider stays outside the button (it must not become part of a tab's target) and the accessibility label/value/traits are unchanged.

### Task 3: Reconcile documentation

- [ ] **Step 1:** In `docs/design/menu-bar-popover/SPEC.md`, state that each provider tab's entire equal-width, full-height region is the pointer target and that the frame + `contentShape` live inside the button label.
- [ ] **Step 2:** In `AGENTS.md` (SwiftUI selection-host geometry guardrails), note that the "expanded frame and `contentShape` inside the `Button` label" rule is now satisfied in both `MenuProviderTabStrip` and `AgentSettingsTabStrip`.
- [ ] **Step 3:** In `docs/product/planning-board.md`, move **Menu popover provider-tab hit areas** off **Deferred** to **Verification**, extend the required outcome to cover the Settings strip too, and point the acceptance at signed-app pointer/keyboard confirmation (recorded as unobserved under the branch waiver until operated).

### Task 4: Verify

- [ ] **Step 1:** `swift build` and the full `swift test` suite pass with no regressions.
- [ ] **Step 2:** `git diff --check` is clean.
- [ ] **Step 3:** Record the signed-app pointer/keyboard acceptance as the remaining gate. Under the branch GUI waiver it is logged as unobserved unless the user operates it; the source change itself is complete and reviewable.

## Acceptance boundary

- Both selectors register a click/hover anywhere within the drawn tab, including the padding around the label, not only on the glyphs.
- No change to which provider is selected for a given interaction, to the switch geometry, or to keyboard/VoiceOver behavior.
- Signed-app pointer + keyboard confirmation is the final visual gate and is recorded honestly (unobserved under the waiver unless user-operated).
