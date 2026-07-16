# Repository Agent Instructions

These instructions apply to the entire repository. More specific instructions in a nested `AGENTS.md` override them for that subtree.

## Documentation discipline

- Update the relevant implementation plan whenever behavior, scope, verification evidence, or a known limitation changes.
- Update `UsageProbe/README.md` and `how-to.md` when a native-app change affects user-visible behavior or operating instructions.
- Use `.agents/skills/preparing-evidence-rich-prs` and `docs/development/evidence-rich-pull-requests.md` when preparing or updating a pull request.
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
- Keep the top Settings `TabView` owned by `SettingsView`. Provider navigation belongs inside the lower Agents content region and must not resize, cover, or shift the top tab bar.
- Preserve native SwiftUI controls and system colors unless a separately approved visual-design task explicitly changes the theme.

## Required visual acceptance for Settings changes

- Compile and build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh`; the raw SwiftPM executable is not sufficient for final macOS UI or permission checks.
- Inspect the actual Settings window at its default size. Source review alone is not visual verification.
- Open every affected tab and check for leading-label clipping, truncated descriptions, controls extending past the trailing edge, content hidden at the bottom, inconsistent section spacing, and movement of the top tab bar.
- Exercise relevant conditional states, including disabled notification controls, missing permission or connection guidance, absent quota values, and long status strings.
- Check both Light and Dark appearance when colors or contrast change. If one appearance cannot be inspected, state that limitation in the implementation plan and handoff instead of claiming complete visual coverage.
- Capture or otherwise directly inspect the original failing page after the fix. Do not infer that a shared-layout change fixed every tab without opening those tabs.
- Do not leave temporary audit app instances running or terminate an app process that was already owned by the user.

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
