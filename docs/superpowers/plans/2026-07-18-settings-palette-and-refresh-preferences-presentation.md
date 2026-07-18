# Settings Palette and Refresh Preferences Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** **Implementation complete — known destination-switch compositor defect deferred.** The user directly inspected the final card presentation across the stated Settings matrix. The page-switch artifact remains reproducible after two rejected workarounds and is deferred by user direction for a dedicated prototype. Its original presentation-only Refresh rows are superseded by the implemented [Refresh-on-Wake plan](2026-07-18-refresh-wake-and-menu-open.md); this plan itself added no automated test case.

**Refresh scope correction — 2026-07-18:** This document's original Figma-derived **Refresh on open** affordance was intentionally not promoted to product behavior. The user rejected it as poor design. Treat any later uncompleted task text that mentions an open preference, `refresh.onOpen`, or `RefreshReason.menuOpen` as historical rejected design, not executable direction. The implemented behavior is the persisted wake-only control in the linked follow-on plan.

**Goal:** Adapt the existing native Settings pages to the v4 Figma card-and-row layout while retaining supported current items, right-aligning General choice controls, porting the dark surface palette, and presenting the requested Refresh options without changing refresh scheduling.

**Architecture:** The existing global sidebar, page header, content width, Context Rail, native controls, and supported settings remain intact. `SettingsView` remains the one owner of the concrete Settings presentation color scheme and injects a value-type `SettingsAppearancePalette` into that hierarchy. Figma-style preference groups use the existing card treatment with leading label/description and trailing native control alignment. The later Refresh-on-Wake plan makes only wake functional while preserving `QuotaMonitor` as the only scheduler and coalescing owner; menu opening stays passive.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit semantic colors for the existing Light presentation, existing `AppSettings`/`QuotaMonitor`, and the signed macOS app build script.

## Source facts and scope boundary

The local v4 design reference is `High-fidelity macOS menu UI v4/src/components/PreferencesWindow.tsx`; it is design evidence only, never an import source or runtime dependency. No Figma URL or Desktop node is available, so this plan cites the checked-in reference rather than claiming a Figma screenshot or variable export.

| Reference location | Confirmed v4 element | Native adaptation in this plan |
| --- | --- | --- |
| lines 554–574 | `Menu Bar Icon` has a trailing `SegmentedControl(["System", "Light", "Dark"])`. | Keep the existing native `Picker(...).pickerStyle(.segmented)`, bind it only to `AppSettings.appearancePreference`, and place it in a trailing-control row. |
| lines 648–672 | `Automatic Refresh` has a native-select-style **Refresh interval** row and trailing **Refresh on wake**/**Refresh on open** switches with the supplied descriptions. | Keep the existing `RefreshMode` picker and implement only the approved wake control. The user rejected Refresh on open; the reference does not add behavior authority. |
| lines 765–773, 794–804, 813–845, 873–884 | Dark window/content is `#1e1e1e`; sidebar/context rail is `#1a1a1a`; search is white at 8% opacity; the primary border/divider is white at 6% opacity. | Resolve the approved values in a single Settings palette and apply them to all owned surfaces, rather than scattering hard-coded colors through pages. |
| lines 130–163 | Section groups use a white 5.5%-opacity dark surface, with white 6%-opacity separators. | Use the palette for Settings and Context Rail cards and their dividers/borders. |
| lines 64–95 | Segment track is white 8%; selected segment and native select fill are `#3a3a3c`; native-select border is white 10%. | Preserve native macOS control behavior; use these values only where native control/container styling can receive them without replacing system control semantics. |

### Exact dark palette inventory

| Token | v4 source value | Planned owner and use |
| --- | --- | --- |
| `windowBackground` | `#1e1e1e` | `SettingsView` root and Settings Page Header background. |
| `sidebarBackground` | `#1a1a1a` | `SettingsNavigationSidebar` background. |
| `pageBackground` | `#1e1e1e` | `SettingsPage` scrollable page background. |
| `contextRailBackground` | `#1a1a1a` | `SettingsContextPanel` background. |
| `sectionSurface` | `white.opacity(0.055)` | `SettingsSection` and `SettingsContextCard` fills. |
| `divider` / `sectionBorder` | `white.opacity(0.06)` | Window dividers, section strokes, and internal Context Rail separators. |
| `searchFieldBackground` | `white.opacity(0.08)` | `SettingsNavigationSidebar` search container. |
| `sidebarSelection` | `white.opacity(0.10)` | Selected destination background only. |
| `sidebarHover` | `white.opacity(0.06)` | Optional hover state, if a native button style needs an explicit background. |
| `popupAndSelectedSegment` | `#3a3a3c` | Bounded menu-picker/selected-segment visual reference; retain native macOS controls when exact styling would change their behavior. |
| `popupBorder` | `white.opacity(0.10)` | Any explicit native-picker container border, only if required after signed visual comparison. |
| `primaryText` / `secondaryText` | `white` / `white.opacity(0.40)` | Use semantic foreground styles unless a palette-consuming custom surface needs an explicit counterpart. |

Light appearance remains on existing AppKit semantic colors (`windowBackgroundColor`, `controlBackgroundColor`, and semantic foreground styles). The v4 color values above are not permission to set `NSApplication.appearance`, `NSWindow.appearance`, application-wide colors, or individual page-local color patches.

## Proposed Figma layout adaptation

The target is the v4 structural layout, not a React/CSS port:

| v4 structure | Current native element retained | Planned adaptation |
| --- | --- | --- |
| Global left navigation, section title, scrollable page, optional right context region | `SettingsNavigationSidebar`, `SettingsPageHeader`, `SettingsPage`, and Context Rail | Keep the current shell, its six destinations, and existing 680 × 560/891 × 560 geometry. |
| Uppercase group title above a rounded card | `SettingsSection` | Preserve the current uppercase title and rounded native card. Align its padding, surfaces, and dividers with the shared palette rather than duplicating custom page layouts. |
| Each preference row has a leading label/description and a trailing fixed-width switch, selector, or segmented control | `SettingsPreferenceToggle`, `SettingsLabeledRow`, and the new `SettingsPreferenceControlRow` | Use the shared trailing-control row for General's Style/Show/Appearance and Refresh's interval/wake/open entries. Keep all current labels, descriptions, and supported values unless this plan explicitly says otherwise. |
| Separators between related rows | Existing section card | Add Figma-style separators only through a shared row-group/container primitive, never as page-local lines. The exact destination scope is the first clarification below. |
| Automatic Refresh group | Current Refresh page | Put the existing writable interval selector first, then the requested visible-but-unavailable wake/open rows; preserve the current read-only Current Policy and Latest Collection information after it. |

The following Figma-only items remain excluded: Show in Menu Bar, Start Minimized, Open on Update, unsupported notification summaries, credit-expiry settings, cache reset, export/log controls, and generated provider controls. No existing supported setting is removed merely to make the page look closer to the mockup.

## Confirmed layout decisions — 2026-07-18

1. **Destination scope:** Apply the Figma row separators and tighter card-row treatment consistently to all six Settings destinations through `SettingsSectionRow`, while retaining their supported current items and behavior.
2. **Refresh behavior follow-on:** The presentation slice initially used truthful unavailable controls. The later implementation persists only wake; the user rejected Refresh on open, so it must be absent rather than clickable or disabled.
3. **Verification:** Run the existing automated suite as regression coverage and perform final visual acceptance manually in an audit-owned signed app. No Figma Design URL or Desktop node is available for screenshot comparison.

## Global constraints

- Preserve the global `SettingsNavigationSidebar`, `SettingsDetailView`, Context Rail, six destinations, 680 × 560 hidden-rail size, and right-only Context Rail expansion.
- Keep `SettingsView` as the single appearance owner. Continue resolving a concrete color scheme through `SystemAppearanceObserver`; do not set `NSApplication.appearance`, `NSWindow.appearance`, recreate a window, or reset selected destination, search query, scroll position, rail state, or focus.
- Use `SettingsPage`, `SettingsSection`, `SettingsLabeledRow`, `SettingsDescription`, shared rows, and `SettingsLayoutMetrics`. Do not add a top-level `Form`, `LabeledContent`, duplicate alignment constants, transparent spacer content, a web runtime, React/CSS, or Figma assets.
- Preserve native SwiftUI controls. A shared row may give a bounded picker or segmented picker a trailing position; it must not replace a native picker or switch with a hand-drawn imitation.
- **No new automated test cases in this slice, by user direction.** Run the existing Swift package suite only as a regression baseline. A later behavior plan introduced persisted wake preference; it added no test case by the same direction.
- This presentation slice itself adds no `AppSettings` keys, persistence, scheduler subscriptions, timers, menu polling, `RefreshReason` cases, diagnostics events, or wake behavior changes. The later wake-only plan preserves `QuotaMonitor` as the sole refresh scheduler and explicitly prohibits menu-open refresh behavior.
- The new UI must not falsely imply that an unavailable Refresh option has changed scheduling. It must expose a noninteractive state and explicit availability information to both sighted users and VoiceOver.

## File structure

| File | Responsibility |
| --- | --- |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceControlRow.swift` | One reusable leading-text/trailing-native-control row for multi-value choices and explicit unavailable controls. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSectionRow.swift` | One shared Figma-style in-card row wrapper with standard inset and optional palette-aware separator. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsAppearancePalette.swift` | Central light-semantic/dark-v4 palette value, injected through `EnvironmentValues`. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift` | Centralize widths/spacing required by the shared row and make Settings surfaces consume the palette. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift` | Resolve the existing concrete scheme once and inject its matching palette across the complete Settings hierarchy. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsNavigationSidebar.swift`, `SettingsPageHeader.swift`, `SettingsContextPanel.swift`, `SettingsContextCard.swift` | Consume the injected palette for all window-owned visible surfaces. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift` | Move Style, Show, and System/Light/Dark Appearance into the shared trailing-control row without altering bindings. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift` | Present the existing interval menu with the shared row and add the two truthful unavailable rows; do not touch monitoring code. |
| Modify `docs/superpowers/plans/2026-07-17-figma-settings-design-completion.md`, `docs/product/planning-board.md`, and `how-to.md` | Link the follow-on scope, record the no-behavior boundary, and document only observed visual verification. |

---

### Task 1: Establish shared Figma-style card rows and trailing controls

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceControlRow.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSectionRow.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`

**Interfaces:**
- Produces `SettingsPreferenceControlRow<Control: View>` for a leading title/optional description and one trailing native control.
- Produces `SettingsUnavailablePreferenceControlRow` for a fixed, inaccessible state with a VoiceOver availability hint.
- Produces `SettingsSectionRow<Content: View>` so all six Settings destinations use the same row inset, vertical rhythm, and palette-aware separator.
- Consumes centralized `preferenceControlMinimumTextWidth`, `unavailableControlStatusSpacing`, `controlWidth`, and `appearanceSegmentedControlWidth`.

- [ ] **Step 1: Add the centralized layout values.**

Add only these metrics to `SettingsLayoutMetrics`; do not put an alignment constant into a page:

```swift
static let preferenceControlMinimumTextWidth: CGFloat = 180
static let unavailableControlStatusSpacing: CGFloat = 4
```

- [ ] **Step 2: Create the shared in-card row wrapper.**

```swift
struct SettingsSectionRow<Content: View>: View {
    let showsDivider: Bool
    private let content: Content
    @Environment(\.settingsAppearancePalette) private var palette

    init(
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, SettingsLayoutMetrics.sectionRowVerticalPadding)
            if showsDivider {
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: SettingsLayoutMetrics.dividerWidth)
            }
        }
    }
}
```

Add `static let sectionRowVerticalPadding: CGFloat = 9` to `SettingsLayoutMetrics`, change `SettingsSection`'s inner stack to `spacing: 0`, and preserve its single outer `sectionContentPadding`. Every section's final row passes `showsDivider: false`.

- [ ] **Step 3: Create the row that mirrors the existing switch geometry.**

```swift
struct SettingsPreferenceControlRow<Control: View>: View {
    let title: String
    let description: String?
    private let control: Control

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayoutMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let description { SettingsDescription(description) }
            }
            .frame(minWidth: SettingsLayoutMetrics.preferenceControlMinimumTextWidth, alignment: .leading)

            Spacer(minLength: SettingsLayoutMetrics.rowSpacing)

            control
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Do not give the trailing control `maxWidth: .infinity`; its fixed width and spacer place its trailing edge with the native switches.

- [ ] **Step 4: Add an explicit unavailable-control wrapper instead of a writable placeholder binding.**

```swift
struct SettingsUnavailablePreferenceControlRow: View {
    let title: String
    let description: String
    let isOn: Bool
    let availability: String

    var body: some View {
        SettingsPreferenceControlRow(title, description: description) {
            VStack(alignment: .trailing, spacing: SettingsLayoutMetrics.unavailableControlStatusSpacing) {
                Toggle(title, isOn: .constant(isOn))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(true)
                Text(availability)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(availability)
            .accessibilityHint("This control does not change refresh scheduling yet.")
        }
    }
}
```

- [ ] **Step 5: Run the existing regression baseline and commit.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
git diff --check
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceControlRow.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSectionRow.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift
git commit -m "Add trailing Settings control rows"
```

Expected: the existing suite passes and the diff has no whitespace errors. Do not create a test case.

### Task 2: Apply the Figma card-and-row structure across all Settings destinations

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift`

**Interfaces:**
- Consumes `SettingsPreferenceControlRow`.
- Consumes `SettingsSectionRow` from Task 1 in every `SettingsSection` across all six destinations.
- Preserves bindings to `settings.menuBarDisplayStyle`, `settings.quotaValueMode`, and `settings.appearancePreference`.
- Produces no new preference, color-scheme owner, or menu-bar appearance behavior.

- [ ] **Step 1: Wrap every Settings-section child in the shared row wrapper.**

For each `SettingsSection`, place each existing logical row, description, button, or conditional guidance block inside `SettingsSectionRow`. Preserve every current condition and value. Use `showsDivider: false` only for the final rendered row in each section; where the final row is conditional, keep the final unconditional content as the no-divider row and leave a preceding conditional row with the default divider.

Do not merge semantically distinct current rows merely to reduce separators. In particular, retain Notification permission guidance, the threshold `ForEach`, Agent provider blocks, Data & Privacy inventory values, Diagnostics export/history sections, Refresh status/readout rows, and all Context Rail content.

- [ ] **Step 2: Replace the three General Menu Bar Icon row containers.**

```swift
SettingsPreferenceControlRow("Style") {
    Picker("Style", selection: $settings.menuBarDisplayStyle) {
        ForEach(MenuBarDisplayStyle.allCases) { style in
            Text(style.title).tag(style)
        }
    }
    .labelsHidden()
    .frame(width: SettingsLayoutMetrics.controlWidth)
}

SettingsPreferenceControlRow("Show") {
    Picker("Show", selection: $settings.quotaValueMode) {
        ForEach(QuotaValueMode.allCases) { mode in
            Text(mode.title).tag(mode)
        }
    }
    .labelsHidden()
    .frame(width: SettingsLayoutMetrics.controlWidth)
}

SettingsPreferenceControlRow("Appearance") {
    Picker("Appearance", selection: $settings.appearancePreference) {
        ForEach(AppearancePreference.allCases) { appearance in
            Text(appearance.title).tag(appearance)
        }
    }
    .labelsHidden()
    .pickerStyle(.segmented)
    .frame(width: SettingsLayoutMetrics.appearanceSegmentedControlWidth)
    .accessibilityLabel("Appearance")
}
```

Keep the two existing descriptions directly below these rows, now without `.settingsValueColumnAligned()`: each is a section-level explanation, not a value-column continuation.

- [ ] **Step 3: Preserve each destination's current information hierarchy.**

Use this migration map exactly:

| Destination | Keep in its current section/card | Figma-row effect |
| --- | --- | --- |
| General | Startup, Keyboard Shortcuts, Menu Bar Icon, Style, Show, Appearance, and existing descriptions | Switches, pop-up choices, and segments all share the trailing edge. |
| Notifications | Master switch, permission guidance, remaining-quota thresholds, forecasts, reset credits, stale data, and refresh failures | Retain disabled states and explanatory text; add separators only through `SettingsSectionRow`. |
| Refresh | Existing interval, effective policy/interval/activity, latest collection, and Refresh Now | The interval and the new presentational controls lead the page; readouts remain visible below. |
| Agents | Provider state, connection actions, and planned-provider copy | Preserve navigation and action ownership; only adopt card row spacing/dividers. |
| Data & Privacy | Local storage and inventory rows | Preserve file paths, text selection, and wrapping; do not clip long values. |
| Diagnostics | Application metadata, diagnostics summary, history, and actions | Preserve existing labels and button behavior; only adopt card row spacing/dividers. |

- [ ] **Step 4: Check boundaries and commit.**

Source-review that `SettingsView` still owns `.preferredColorScheme`, the controls retain their bindings, and neither `NSApplication.appearance` nor `NSWindow.appearance` is assigned. Run the existing package suite and `git diff --check`; add no test case.

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift
git commit -m "Apply Figma Settings card rows"
```

### Task 3: Port the v4 dark palette through one Settings-owned environment value

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsAppearancePalette.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`, `SettingsLayout.swift`, `SettingsNavigationSidebar.swift`, `SettingsPageHeader.swift`, `SettingsContextPanel.swift`, and `SettingsContextCard.swift`

**Interfaces:**
- Produces `SettingsAppearancePalette.resolve(for:)` and `EnvironmentValues.settingsAppearancePalette`.
- `SettingsView` computes `presentationColorScheme` once from the existing `AppearancePreference` and `SystemAppearanceObserver`, then supplies both the matching palette and `.preferredColorScheme(presentationColorScheme)`.
- Every Settings-owned custom background/stroke reads `@Environment(\.settingsAppearancePalette)`; individual page views do not choose their own dark colors.

- [ ] **Step 1: Define the palette and environment key.**

```swift
struct SettingsAppearancePalette {
    let windowBackground: Color
    let sidebarBackground: Color
    let pageBackground: Color
    let contextRailBackground: Color
    let sectionSurface: Color
    let divider: Color
    let searchFieldBackground: Color
    let sidebarSelection: Color

    static func resolve(for colorScheme: ColorScheme) -> Self {
        if colorScheme == .dark {
            return Self(
                windowBackground: Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255),
                sidebarBackground: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
                pageBackground: Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255),
                contextRailBackground: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255),
                sectionSurface: .white.opacity(0.055),
                divider: .white.opacity(0.06),
                searchFieldBackground: .white.opacity(0.08),
                sidebarSelection: .white.opacity(0.10)
            )
        }

        return Self(
            windowBackground: Color(nsColor: .windowBackgroundColor),
            sidebarBackground: Color(nsColor: .windowBackgroundColor),
            pageBackground: Color(nsColor: .windowBackgroundColor),
            contextRailBackground: Color(nsColor: .windowBackgroundColor),
            sectionSurface: Color(nsColor: .controlBackgroundColor),
            divider: .quaternary,
            searchFieldBackground: Color(nsColor: .controlBackgroundColor).opacity(0.7),
            sidebarSelection: Color(nsColor: .controlBackgroundColor)
        )
    }
}
```

Add a private `EnvironmentKey` with a light palette default and an `EnvironmentValues.settingsAppearancePalette` accessor in the same file. Do not include text colors or custom toggle colors; existing semantic foregrounds and native control rendering remain authoritative.

- [ ] **Step 2: Inject the single existing presentation scheme.**

In `SettingsView`, introduce:

```swift
private var presentationColorScheme: ColorScheme {
    settings.appearancePreference.presentationColorScheme(system: systemAppearance.colorScheme)
}

private var appearancePalette: SettingsAppearancePalette {
    SettingsAppearancePalette.resolve(for: presentationColorScheme)
}
```

Replace the inline `.preferredColorScheme(...)` argument with `.preferredColorScheme(presentationColorScheme)` and add `.environment(\.settingsAppearancePalette, appearancePalette)` at the same outer boundary. Do not change `SystemAppearanceObserver`, `AppearancePreference`, or any AppKit appearance assignment.

- [ ] **Step 3: Replace owned surfaces, not native control semantics.**

| View | Required substitution |
| --- | --- |
| `SettingsPage` | `pageBackground` |
| `SettingsSection` | `sectionSurface` and `divider` for its stroke |
| `SettingsNavigationSidebar` | `sidebarBackground`, `searchFieldBackground`, and `sidebarSelection` |
| `SettingsPageHeader` | `windowBackground` |
| `SettingsContextPanel` | `contextRailBackground` |
| `SettingsContextCard` | `sectionSurface` and `divider` for its stroke |
| `SettingsView` dividers | a palette-aware one-point divider without changing rail/window geometry |

Do not apply `#3a3a3c`, an opacity overlay, or a hard-coded color directly in General, Refresh, Notifications, Agents, Data & Privacy, or Diagnostics. Do not restyle the native switch, picker, button, title bar, or native menu merely to imitate React/CSS.

- [ ] **Step 4: Build and commit.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
git diff --check
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings
git commit -m "Port Settings dark surface palette"
```

Do not add a test case.

### Task 4: Historical presentation-only Refresh proposal — superseded

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Do not modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`, `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`, or `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitoringState.swift`

**Interfaces:**
- Consumes the two rows from Task 1.
- Keeps the existing writable `$settings.refreshMode` binding and every `RefreshMode.allCases` option.
- Was limited to presentation before behavior approval. It is superseded by the wake-only follow-on plan; do not implement an open control or menu callback from this historical task.

- [ ] **Step 1: Make the existing selector a trailing native Refresh interval menu.**

Move the existing picker into a first `SettingsSection("Automatic Refresh")`, rename its visible label from **Refresh frequency** to **Refresh interval**, and retain every existing actual option including **Automatic** and **1 minute 30 seconds**:

```swift
SettingsPreferenceControlRow("Refresh interval") {
    Picker("Refresh interval", selection: $settings.refreshMode) {
        ForEach(RefreshMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
        }
    }
    .labelsHidden()
    .frame(width: SettingsLayoutMetrics.controlWidth)
    .accessibilityLabel("Refresh interval")
}
```

Do not replace `RefreshMode` with the v4 mockup's shorter option list: that would silently change supported behavior. Keep the read-only **Current Policy** and **Latest Collection** sections unchanged.

- [x] **Step 2: Supersede the presentation-only wake/open rows.**

```swift
The later behavior plan replaces the unavailable wake row with a persisted native switch. It removes the open row entirely after user rejection. Do not restore it as a disabled, planned, or interactive control.
```

Wake is no longer unconditional: `QuotaMonitor` consults the persisted wake preference. Native-menu opening has no `RefreshReason` or callback.

- [x] **Step 3: Record the final behavior boundary.**

The follow-on plan adds only `AppSettings.refreshOnWake` with migration default `true`. Only `QuotaMonitor` consults it before its existing wake callback. A menu opening must not request any monitor action, timer, polling loop, menu-tree state watcher, or second scheduler.

- [ ] **Step 4: Run the existing regression baseline and commit.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
git diff --check
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift
git commit -m "Present upcoming Refresh preferences"
```

Do not add a test case.

### Task 5: Document evidence and perform direct visual acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-figma-settings-design-completion.md`, `docs/product/planning-board.md`, `how-to.md`, and this plan.

**Interfaces:**
- Records only direct signed-app observations and leaves unobserved cells as **Not run**.
- Adds no PR, push, test case, runtime setting, permission, dependency, migration, or compatibility change.

- [ ] **Step 1: Reconcile plan and board scope.**

In the original Figma completion plan, replace its obsolete blanket exclusion of refresh-on-wake/open with a link to this plan and state that the controls are separately approved for presentation only. Add this plan to the planning-board index and a **Queued** Settings slice row whose next action is Task 1 implementation; keep Product Follow-up 5 **Queued**.

- [x] **Step 2: Update user-facing guidance after implementation.**

In `how-to.md`, describe the Refresh page precisely: **Refresh interval** changes the existing schedule; **Refresh on wake** defaults on and is configurable; there is no Refresh-on-open option, and opening the menu does not refresh it.

- [ ] **Step 3: Directly inspect the signed app before completion.**

Open only an audit-owned signed app instance through normal UI paths. At 680 × 560 hidden rail and 891 × 560 visible rail, inspect:

1. General **Style**, **Show**, and all three **Appearance** segments share the trailing alignment of native switches and preserve existing values.
2. Refresh interval is bounded and right aligned; the persisted wake switch is interactive; no Refresh-on-open control appears; and opening the native menu does not schedule work.
3. General, Refresh, Notifications, Agents, Data & Privacy, and Diagnostics in Light and Dark: page/header, sidebar, Context Rail, section/card fills, dividers, selected sidebar item, and search background have no stale/mixed region.
4. Light → System while macOS is Dark; Dark → System while macOS is Light; System → Light → System; System → Dark → System; and a macOS appearance change while Settings stays open. Confirm destination, search text, scroll location, Context Rail visibility, preview state, and focused control survive.
5. The native menu still follows macOS, not the Settings preference. Do not add menu refresh behavior or a timer.

If normal UI automation cannot inspect a state, stop promptly, do not terminate a user-owned app, and record that cell as **Not run**.

- [ ] **Step 4: Record exact verification and commit documentation.**

Run the existing package suite, signed build, strict code-sign verification, plist lint, and `git diff --check`. Record every visual **Observed**/**Not run** cell in this plan and board. Do not create a PR or push.

```bash
git add docs/superpowers/plans docs/product/planning-board.md how-to.md
git commit -m "Document Settings palette and Refresh presentation"
```

## Deferred behavior

The disabled Refresh rows are visual evidence of supported future intent, not settings. A later implementation must separately approve persistence, defaults, migration, user-visible state, monitor ownership, coalescing, diagnostics, and the smallest deterministic regression coverage before it enables either switch. It must never make opening a native `MenuBarExtra` a polling surface or second scheduler.

## Layout regression record — 2026-07-18

During direct signed-app inspection, reusing a palette `Rectangle` constrained only by width inside both `HStack` and `VStack` contexts caused the vertical-page instance to consume the available height. The visible result was a large empty upper panel, controls pushed into a lower region, and apparently broken scrolling. The repair separates fixed-width vertical and fixed-height horizontal dividers.

General initially reached the page's trailing edge because the fixed 240-point segmented picker, 180-point leading-text minimum, inter-column spacing, and section/page padding exceeded the 499-point Settings Page budget. The repair uses centralized smaller bounded segments and leading minimum values that fit the page, with `SettingsSectionRow` explicitly filling its available width. The card density repair removes stacked outer vertical card padding and retains one 12-point row inset plus horizontal-only card padding. General's launch and keyboard controls share one dense card, while its control explanations use the same leading-column rhythm as the Notifications master switch.

These causes and the destination-identity prevention rule are recorded in `AGENTS.md` under **Settings card geometry and mixed-axis layout guardrails**. The signed-app visual matrix remains open until the user confirms the repaired General width/density and the full cross-destination Light/Dark/rail matrix.

### Destination-switch rendering boundary — 2026-07-18

The user observed one or two frames of the prior page's text while changing between General and Notifications. This is not selected-destination persistence: `AppSettings.selectedSettingsTab` is an in-memory `@Published` value written directly by `SettingsNavigationSidebar`, with no disk read, task, timer, or declared selection animation. Both destination branches enter the same `SettingsPage`/`ScrollView` host through `SettingsDetailView`.

An identity-scoped experiment using `.id(settings.selectedSettingsTab)` was rejected after direct slow-motion observation: it made the behavior worse by treating the switch as removal/insertion and visibly fading/overlapping old and new text. A second experiment centralizing a disabled-animation transaction for sidebar and menu routes also left the defect visible in the signed app. Both experiments were reverted. The remaining cause must be isolated in a dedicated prototype that compares the existing branch switch, a native selection container, and an AppKit-hosted alternative with raw signed-app frame capture before another repair is attempted.

No new automated test case is added by user direction. The deferred repair's future signed-app regression boundary is rapid repeated switching across all six destinations, including both Context Rail states; no transition is currently claimed fixed.

### Video inspection evidence — 2026-07-18

The user-provided `tab switch text bug.mov` is a 5.95-second, 60 fps recording of the current signed app. Its raw General → Notifications frames reproduce the defect: interleaved frames at 3.033, 3.067, and 3.100 seconds contain duplicated/displaced text across the full Settings hierarchy, including the unchanged sidebar and header, while adjacent frames settle correctly. The artifact is therefore not a Notifications-card spacing change or a delayed persisted selection; it is a whole-hierarchy SwiftUI/AppKit compositing transaction during sidebar selection.

The failed `.id(settings.selectedSettingsTab)` experiment remains reverted because it introduced a visible removal/insertion fade. The subsequent disabled-animation route-transaction experiment also remains reverted: direct signed-app acceptance showed that it did not eliminate the artifact. The existing package suite, signed build, signature, plist, and diff checks are regression baseline only; they do not establish a compositor repair. The defect is explicitly deferred until the documented prototype comparison can produce raw signed-app frame evidence.

### User-observed Settings acceptance — 2026-07-18

The user directly inspected and accepted the final General trailing gutter and compact card density. The user also directly inspected all six Settings destinations with the Context Rail hidden and visible, Light and Dark appearance, relevant conditional states, scrolling, keyboard traversal, VoiceOver, focus preservation, and the native-menu appearance boundary. Those observations apply to the completed card/palette presentation; they do not resolve the separately deferred destination-switch compositor defect or replace the separately documented System-appearance transition matrix.

### Implementation evidence — 2026-07-18

- **Run:** the existing package suite passed (8 tests, 0 failures) and the signed build/signature/plist/diff checks passed for the rejected experiments. No test case was added by user direction; this is existing regression coverage only and is not acceptance evidence for the issue.
- **Observed:** the initial signed-app audit exposed the divider expansion and General width/density regressions. After the axis-specific divider repair, the user confirmed the empty upper panel was gone and Settings scrolling was restored.
- **Observed:** the user accepted the final compact-card/General-gutter revision and the stated six-destination, rail-hidden/visible, Light/Dark, conditional-state, scrolling, keyboard, VoiceOver, focus-preservation, and native-menu appearance matrix.
- **Deferred:** a successful destination-switch compositor repair. The `.id` and disabled-animation transaction trials failed and are absent from production source. The separate live System-appearance transition matrix remains **Not run**.

## Acceptance criteria

- General **Style**, **Show**, and **Appearance** use a common leading-text/trailing-native-control layout; Appearance stays a bounded native System/Light/Dark segmented picker.
- The dark palette applies the exact v4 surface values through one `SettingsView`-injected palette: `#1e1e1e`, `#1a1a1a`, white 5.5%, 6%, 8%, and 10% overlays, and `#3a3a3c` only where native-control compatibility permits. Light continues using semantic system colors.
- No Settings surface holds an ad hoc dark color; pages share the same effective appearance, and no AppKit/application-wide appearance assignment is added.
- Refresh presents **Refresh interval** and the persisted **Refresh on wake** control in the v4-inspired leading-label/trailing-control format. No Refresh-on-open control appears.
- Refresh interval retains its supported selection and behavior. Wake defaults on but persists its setting; menu opening remains passive.
- No new automated test case is added. Existing tests serve only as a regression baseline; later behavior wiring has an explicit deterministic-regression requirement.
- The signed-app visual matrix is recorded as direct observation or **Not run** without inference. No PR is created or pushed by an agent.
