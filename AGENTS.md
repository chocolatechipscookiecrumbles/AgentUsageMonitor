# Repository Agent Instructions

These instructions apply to the entire repository. More specific instructions in a nested `AGENTS.md` override them for that subtree.

## Documentation discipline

- Update the relevant implementation plan whenever behavior, scope, verification evidence, or a known limitation changes.
- Update `UsageProbe/README.md` and `how-to.md` when a native-app change affects user-visible behavior or operating instructions.
- Use `.agents/skills/preparing-evidence-rich-prs` and `docs/development/evidence-rich-pull-requests.md` when preparing or updating a pull request.
- The user creates every GitHub pull request manually. For every approved push or planned-PR request, push only the approved scope and generate a filled draft from `.github/pull_request_template.md` (including the compare URL) for the user to submit. Never create a GitHub pull request.
- Keep automated test changes narrow: do not add broad test suites or general test cases by default. For a reproducible defect, add the smallest deterministic regression test that demonstrates the old failure and protects the fix; if a regression test is not feasible, record the manual regression boundary and why.
- Preserve existing user changes and keep unrelated edits out of the current task.

## macOS Settings UI guardrails

The July 14 Settings audit found that macOS SwiftUI `Form` and `LabeledContent` can calculate an implicit label column that extends outside the visible content area. In this app it clipped the leading text in General and Refresh, stretched pickers across the window, crowded Notifications against the bottom edge, and made caption-sized status text hard to read.

When editing `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings`:

- Build preference pages with the shared `SettingsPage`, `SettingsSection`, `SettingsLabeledRow`, and `SettingsDescription` components in `SettingsLayout.swift`.
- Do not reintroduce a top-level `Form` or rely on its implicit macOS label-column alignment without a documented reason and signed-app visual evidence that it does not clip at the default window size.
- Keep label widths and value-column offsets in `SettingsLayoutMetrics`; do not duplicate alignment constants in individual pages.
- Keep long pages vertically scrollable. Content must remain reachable at the default 680 × 560-point Settings content size.
- Bound wide controls such as pop-up pickers instead of allowing them to consume every available horizontal point.
- Let explanatory and status text wrap vertically. Use adaptive system foreground styles and at least callout-sized text for information a user needs to understand or recover from a state.
- Use explicit stack spacing. Do not create section gaps with transparent footer views such as `Color.clear.frame(height:)`.
- Keep `SettingsView` as the owner of the global `SettingsNavigationSidebar`, selected destination, `SettingsDetailView`, and Context Rail visibility. The sidebar and Settings Page frames must remain stable when the rail is hidden or shown; provider navigation belongs inside the Agents destination and must not create a second window-level navigation owner.
- Preserve native SwiftUI controls and system colors unless a separately approved visual-design task explicitly changes the theme.

## Required visual acceptance for Settings changes

- Compile and build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh`; the raw SwiftPM executable is not sufficient for final macOS UI or permission checks.
- Inspect the actual Settings window at its default size. Source review alone is not visual verification.
- Open every affected tab and check for leading-label clipping, truncated descriptions, controls extending past the trailing edge, content hidden at the bottom, inconsistent section spacing, and movement of the top tab bar.
- Exercise relevant conditional states, including disabled notification controls, missing permission or connection guidance, absent quota values, and long status strings.
- Check both Light and Dark appearance when colors or contrast change. If one appearance cannot be inspected, state that limitation in the implementation plan and handoff instead of claiming complete visual coverage.
- Capture or otherwise directly inspect the original failing page after the fix. Do not infer that a shared-layout change fixed every tab without opening those tabs.
- Do not leave temporary audit app instances running or terminate an app process that was already owned by the user.

## Settings card geometry and mixed-axis layout guardrails

The July 18 Figma-layout audit found that a shared palette divider constrained only with `.frame(width: 1)` worked in an `HStack` but expanded to absorb the available height when reused in the Settings page's `VStack`. This split the page into a large empty upper region and a compressed lower region, which made the actual controls appear non-scrollable. The same audit found that General's fixed segmented control, leading-text minimum width, and card padding exceeded the 499-point Settings Page width, allowing that card to reach the trailing edge while other pages retained a gutter. Nested card and row vertical padding also made one-item cards visibly over-tall.

When changing Settings rows, cards, or dividers:

- Do not reuse an unconstrained `Rectangle` divider across axes. A vertical divider must set its width; a horizontal divider must set its height. Prefer a shared `SettingsPaletteDivider` with an explicit orientation when both are needed.
- Calculate the complete width budget at the default hidden-rail Settings Page width before adding a fixed trailing control: page width minus page horizontal padding minus section horizontal padding must accommodate the leading-text minimum width, inter-column spacing, and control width. A child `.frame(maxWidth: .infinity)` does not prevent intrinsic-width overflow.
- Keep every width, inset, row-padding, and title/description-spacing value in `SettingsLayoutMetrics`. Use one `SettingsPreferenceControlRow` for leading title/description plus trailing native picker/segment and one `SettingsPreferenceToggle` for Boolean controls.
- Use `SettingsSectionRow` for the common Figma card row treatment. It owns the row's vertical inset and separator; `SettingsSection` owns only horizontal card inset. Do not stack additional vertical container padding around every row.
- Keep a control's explanatory description inside its leading control row whenever it explains that specific control. It must share the same width and `preferenceTitleDescriptionSpacing` as the Notifications master-toggle description; use standalone `SettingsDescription` only for section-level policy or recovery information.
- Keep General's related one-line controls in a single dense card where that improves scanability. Do not create a separate oversized card solely because it contains one toggle.
- Do not apply `.id(selectedDestination)` to the full Settings detail subtree to mask a page-switch rendering defect. It turns a destination switch into removal/insertion and can visibly overlap or fade old and new page text. Trace the triggering transaction and host reuse first; never put a destination identity on `SettingsView`, the window, or the appearance owner.
- The recorded Settings destination-switch defect can transiently duplicate and displace text across the whole window. The tested detail-subtree identity and disabled-animation transaction workarounds did not correct it and are prohibited as fixes. Defer further changes until a dedicated prototype can compare the existing branch switch, a native selection container, and an AppKit-hosted alternative with signed-app frame capture.
- Before accepting a shared geometry change, inspect General and Notifications side by side at the default size with the Context Rail both hidden and visible. Check for empty regions, normal scrolling, equal card gutters, compact one-item cards, wrapped descriptions that do not run under controls, and fixed controls contained inside the page.

## Settings appearance-transition guardrails

The July 15 appearance audit found that changing a live Settings root from `.preferredColorScheme(.light)` to `.preferredColorScheme(nil)` does not reliably clear SwiftUI's presentation-level override. The picker persists **System** and AppKit chrome follows Dark, while the hosted SwiftUI content can remain Light, producing a mixed window with dark outlines/title bar and light page/card bodies.

When changing System/Light/Dark behavior:

- Treat appearance as a Settings-presentation concern. Keep `SettingsView` as the one owner and always supply a concrete `preferredColorScheme`; do not also mutate `NSWindow.appearance` from inside that SwiftUI hierarchy.
- **System** remains a distinct persisted preference, but its presentation resolves from a live observation of `NSApplication.effectiveAppearance`. Do not resolve it only once, because the open Settings window must continue following later macOS appearance changes.
- Read the application's effective appearance, but do not assign `NSApplication.appearance`; native `MenuBarExtra` presentation must remain system-controlled. Do not use `.id(...)`, delayed window writes, or window recreation to hide propagation bugs. Appearance changes must preserve the selected destination, search query, scroll position, preview visibility, and control focus.
- Keep one owner for the entire Settings window so title bar, Navigation Sidebar, Settings Page, cards, controls, dividers, and Context Rail resolve through the same effective appearance. Do not patch individual Light-looking surfaces with hard-coded colors.
- Preserve semantic system colors. A mixed transition is an ownership/propagation failure, not justification for replacing `windowBackgroundColor`, `controlBackgroundColor`, or semantic foreground styles.

Before claiming an appearance fix complete:

- Reproduce the original **Light → System while macOS is Dark** transition in the signed app and directly inspect the same live Settings window after the change.
- Exercise Light → System under System Dark, Dark → System under System Light, System → Light → System, System → Dark → System, and a macOS appearance change while the Settings window remains open.
- Inspect all six Settings destinations with the Context Rail visible and hidden. Confirm there is no mixed title-bar/content state, stale card fill, incorrect divider contrast, or region that updates only after reopening.
- Confirm destination selection, search text, scroll position, preview state, and keyboard focus survive each appearance transition.
- Open the native menu before and after forcing Settings Light/Dark and confirm it still follows macOS rather than the Settings preference.
- Build and inspect the signed `.app`. An isolated `NSHostingView` harness can prove the propagation mechanism but is not final visual evidence.

## Regression warning signs

Stop and perform a visual audit if a Settings change introduces any of the following:

- a new top-level `Form` in a preference page;
- a new `LabeledContent` outside `SettingsLabeledRow`;
- a hard-coded alignment padding that duplicates `SettingsLayoutMetrics`;
- caption-sized permission, failure, recovery, or scheduling text;
- transparent spacer content;
- an unbounded picker or long single-line description;
- a Settings frame reduction without checking all six top tabs and the longest page;
- a completion claim based only on compilation or source inspection.
- a System appearance implementation that changes only SwiftUI content or only AppKit window chrome;
- a Light/Dark fix that sets application-wide appearance and unintentionally recolors the native menu;
- an appearance bridge inside the SwiftUI Settings hierarchy that competes with its containing scene for `NSWindow.appearance`;
- an appearance transition that requires closing/reopening Settings or resets its session state.

## Notification episode guardrails

The July 14 interruption audit found that keeping one consecutive-failure counter in the monitor and another in notification policy caused scheduling and delivery to drift. The notification counter also generated a new key for every group of three failures, so one continuing outage could repeatedly alert the user.

When changing refresh-failure, stale-data, connection, or recovery notifications:

- Keep episode state in one owner. `QuotaMonitor` owns refresh-interruption counts, transitions, persistence, and scheduling; notification policy consumes its typed state and must not introduce a parallel failure counter.
- Model one continuing problem as one durable episode with a stable identifier. Do not derive a new delivery key from an increasing failure count, retry number, elapsed-time bucket, or app launch.
- Define the recovery boundary explicitly. A confirmed result ends the interruption episode and restores the user-selected cadence; another failed retry does neither.
- Treat authentication/setup failures separately from operational interruptions. Missing Codex CLI and signed-out states use the connection UI and must not consume or trigger the disconnection-style alert.
- Suppress overlapping operational alerts for the same cause. While a refresh interruption is active, do not also emit recurring stale-data notifications for that same lack of confirmed updates.
- Keep notification permission, the app master switch, the category switch, transition eligibility, persisted delivery deduplication, and retry scheduling as separate gates. Trace all six before claiming a notification control or policy works.
- Use cautious copy for inferred causes. A failed provider refresh may mean the user is disconnected, but it does not prove that the internet is unavailable.
- Verify restraint, not only first delivery: observe failures one and two, the third-failure alert, additional ten-minute retries, relaunch during the same episode, manual retry, and confirmed recovery.

## GUI audit command safety

- Do not attach LLDB to an already running app merely to open or focus a Settings window; debugger attachment can wait indefinitely and is not visual acceptance evidence.
- Open the signed app through normal UI paths. If macOS Accessibility or foreground-control permissions prevent automated navigation, stop the audit command promptly, record the limitation in the active plan, and leave the remaining visual check for manual acceptance.
- Track every temporary audit process before launch and close only the instance started by the audit. Never terminate a pre-existing user-owned app process.

## Native menu dynamic-update guardrails

The July 2026 refresh-row audits established that a SwiftUI `MenuBarExtra` can continue drawing updated text while AppKit's tracked row geometry and highlight map become stale. A timer-interval `Text` previously caused recursive `MenuBehavior.menuNeedsUpdate`/AttributeGraph crashes, and a child `@ObservedObject` publishing a different countdown string every second later reproduced scrolling and pointer highlights above the intended row. Replacing that child with one event-driven, absolute-time row restored correct interaction in the signed menu.

When changing `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu`:

- Treat visible content, row identity, row geometry, hit testing, keyboard navigation, and highlight placement as one native-menu acceptance boundary.
- Do not add `TimelineView`, timer-interval `Text`, a per-second child `ObservableObject`, or per-second root invalidation to the production `MenuBarExtra`.
- Keep the row count, row type, identity, and width envelope stable while the menu is tracking. Publish only semantic events such as refresh start, refresh completion, connection transition, or a new schedule.
- Prefer an absolute next-refresh time when the native menu does not own a safe ticking surface. Do not label a static relative value as a live countdown.
- Keep connection/status polling and refresh scheduling outside the SwiftUI menu tree. A background state check may publish a semantic transition; opening or redrawing the menu must not become the scheduler.
- Require a separate product decision, ADR, and prototype before restoring a true dynamic countdown. Compare an AppKit-owned fixed-geometry row, a window-style popover, and the stable native-menu alternative explicitly; do not reach into SwiftUI's private `NSMenu`.

Before accepting any native-menu dynamic update:

- Build and launch the signed `.app`, then inspect the actual `MenuBarExtra`; an isolated `NSHostingView`, source review, or compilation is not interaction evidence.
- Keep the menu open across every affected semantic transition, point across every row, scroll above and below the visible command area, and activate the visibly highlighted command.
- Check Light and Dark appearance, keyboard and VoiceOver navigation, long/localized content, repeated open/close cycles, and new crash reports. Record states that cannot be manufactured instead of inferring coverage.
