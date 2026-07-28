# Agent Token Monitor Settings Implementation Plan

> **Status (2026-07-28): Planned, not started.** Adds a per-agent **Token Monitor** section to the Agents Settings Destination that shows or hides the menu-popover Token Monitor card and chooses which of its parts appear. It also renames the card itself to Token Monitor so one feature carries one name.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each supported agent its own **Token Monitor** section in Settings with one master show/hide toggle plus four section toggles (Activity chart, Token categories, Model usage, Last request), so a user can remove the card entirely for an agent or trim it to the parts they care about. Adopt **Token Monitor** as the single name for the feature in Settings, in the card, and in the vocabulary.

**Architecture:** Preferences are stored per provider in `AppSettings` using the same per-provider key pattern the remaining-quota thresholds already use. One shared `AgentTokenMonitorSection` view renders the controls in both agent pages, mirroring `AgentUsageWarningsSection`. The master toggle is a collection control, not only a display filter: turning it off stops that provider's file observer and scans and drops its cached requests from disk. The four section toggles are display-only, because every section derives from the same reconciled request set.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, `UserDefaults` through `AppSettings`. No new dependency, no new persistence file, no network call.

## Global Constraints

- The card's identity — **Token Monitor**, **This Mac · observed**, the day's total, and the `N requests` caption — is never hideable. Section toggles remove sections below the header only. A card with every section hidden still states what it is and what it observed.
- The master toggle governs collection, not just rendering. When it is off for a provider, that provider's FSEvents observer is stopped, its scans are cancelled, its in-memory requests are cleared, and its entry is removed from `token-activity-cache.json`. Reading records the user has chosen not to see is not acceptable.
- The four section toggles must never change collection or reconciliation. Every section is derived from one reconciled request set, so hiding one cannot change another's numbers.
- Turning the master toggle back on re-reads from scratch. Do not retain a hidden provider's data in memory or on disk "just in case".
- Defaults preserve today's behavior: the Token Monitor is visible and all four sections are enabled for every supported provider. A first launch after this change must look identical to before it.
- Follow the existing per-provider preference pattern (`Key.enabledQuotaThresholds(for:)`). Do not introduce a global Token Monitor preference that a later per-agent requirement would have to migrate away from.
- Build preference rows with `SettingsSection`, `SettingsSectionRow`, and `SettingsPreferenceToggle`. Do not add a `Form`, a `LabeledContent` outside `SettingsLabeledRow`, or a hard-coded alignment padding that duplicates `SettingsLayoutMetrics`.
- Keep every new width, spacing, and inset in `SettingsLayoutMetrics`. Explanatory text stays at least callout-sized and wraps vertically; do not create section gaps with transparent spacer views.
- Preserve the 340-point, non-scrolling popover and its provider-intrinsic height. Do not reintroduce a minimum-height floor, and keep the shared 12-point content-to-footer gap outside the provider switch.
- Do not add feature-presence, happy-path, or toggle-round-trip tests. Add automated coverage only for a reproducible defect, as the smallest deterministic regression. Otherwise record the manual regression boundary.
- Production Swift changes require the main macOS `xcodebuild`, the full existing suite, and the signed `.app` from `CodexUsageMonitor/Scripts/build-app.sh`. Settings changes additionally require the visual acceptance in AGENTS.md: inspect at the default 680 × 560 size with the Context Rail hidden and visible, in Light and Dark.
- Update `CONTEXT.md`, `docs/product/planning-board.md`, `how-to.md`, `outline.md`, `UsageProbe/README.md`, and `docs/superpowers/plans/2026-07-14-dashboard.md` when behavior, scope, or a limitation changes.

---

## Naming

**Token Monitor** is the chosen name, decided on 2026-07-28.

It replaces two earlier candidates. "Dashboard" was retired in `docs/superpowers/plans/2026-07-14-dashboard.md` because it used to mean a separate window that is not being built, and "Token Activity" is the term currently in `CONTEXT.md` and on the card's own header.

The rename therefore applies everywhere the user can read it, not only to the new Settings section — a Settings section named one thing controlling a card named another is the exact problem the decision exists to avoid:

- the card header string (`ProviderTokenActivityPresentation.title`, currently `"Token activity"`);
- the new Settings section title and its master toggle;
- the `CONTEXT.md` vocabulary entries;
- the operating documentation in `how-to.md`, `outline.md`, and `UsageProbe/README.md`.

Existing Swift type names (`ProviderTokenActivityCard`, `ProviderTokenActivityPresentation`, `LocalActivityMonitor`, and the `Activity/` directory) are deliberately **not** renamed. They are internal identifiers, the vocabulary rule governs what a user reads, and a type-wide rename would add churn and review surface to a change whose value is entirely in the copy. Task 5 records this so a later reader does not treat the mismatch as an oversight.

## The popover height problem is deferred

`docs/superpowers/plans/2026-07-14-dashboard.md` records that the tallest Codex tab measures 929 points against roughly 931 usable points on a 13.6-inch MacBook Air and roughly 775 at 1280×800.

That problem is **deferred by direction on 2026-07-28** and now tracked on the Bug-fix board as *Token Monitor card makes the popover taller than a laptop screen*. This plan does not attempt to fix it and must not be described as fixing it: a default install is unchanged and still 929 points.

Two things still connect the two:

- The section toggles give a user a workaround on a small screen. That is a workaround, not a fix, because it requires the user to find and use it.
- Task 6 measures what each hidden section actually saves. Those numbers belong in the deferred item's record, because they are exactly what a future fix will be judged against.

Approximate savings, to be replaced with measured values in Task 6:

| Section hidden | Approximate saving |
| --- | --- |
| Activity chart | ~104 pt (84 pt plot, 14 pt hover line, spacing) |
| Token categories | ~50 pt (two rows plus divider) |
| Model usage | ~86 pt at four rows, plus divider |
| Last request | ~50 pt (two lines plus divider) |
| Master toggle off | the whole card, plus one 12-point content gap |

---

## File Structure

### New files

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/TokenMonitorSection.swift` — the four toggleable card sections, their titles, and their descriptions.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentTokenMonitorSection.swift` — the shared Settings section rendering the master toggle and the four section toggles for one provider.

### Modified files

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift` — per-provider Token Monitor visibility and section preferences.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift` — renders `AgentTokenMonitorSection`.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift` — renders `AgentTokenMonitorSection`.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityCard.swift` — renders only the enabled sections, with dividers between rendered sections only.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift` — omits the card when the provider's Token Monitor is hidden.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift` — omits the card when the provider's Token Monitor is hidden.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift` — starts and stops per-provider collection and purges a disabled provider's cache.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — forwards visibility changes to the monitor.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift` — states that hiding an agent's Token Monitor stops reading its records.
- `CONTEXT.md`, `how-to.md`, `outline.md`, `UsageProbe/README.md`, `docs/product/planning-board.md`, `docs/superpowers/plans/2026-07-14-dashboard.md` — vocabulary, operating guidance, and gate measurements.

---

### Task 1: Store Token Monitor preferences per agent

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/TokenMonitorSection.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`

**Interfaces:**

- Produces: `TokenMonitorSection` (`.activityChart`, `.tokenCategories`, `.modelUsage`, `.lastRequest`), `AppSettings.isTokenMonitorVisible(for:)`, `AppSettings.setTokenMonitorVisible(_:for:)`, `AppSettings.isTokenMonitorSectionEnabled(_:for:)`, `AppSettings.setTokenMonitorSection(_:enabled:for:)`, and the published `tokenMonitorVisibilityByProvider`.

- [ ] **Step 1:** Create `TokenMonitorSection.swift`. `allCases` order is the card's rendering order and Task 2 depends on that.

```swift
import Foundation

/// One toggleable region of the Token Monitor card, in rendering order.
///
/// The card's header — its title, `This Mac · observed`, the day's total, and
/// the request count — is deliberately absent here. A card that cannot say
/// what it is and what it observed is not worth rendering at all.
enum TokenMonitorSection: String, CaseIterable, Identifiable, Sendable {
    case activityChart
    case tokenCategories
    case modelUsage
    case lastRequest

    var id: Self { self }

    var title: String {
        switch self {
        case .activityChart: "Activity chart"
        case .tokenCategories: "Token categories"
        case .modelUsage: "Model usage"
        case .lastRequest: "Last request"
        }
    }

    var settingsDescription: String {
        switch self {
        case .activityChart:
            "The 30-minute bars from midnight through the current interval."
        case .tokenCategories:
            "Today's totals for each token category this agent reports."
        case .modelUsage:
            "The largest model groups and their share of today's tokens."
        case .lastRequest:
            "The most recent request observed on this Mac, with its model."
        }
    }
}
```

- [ ] **Step 2:** Add the storage keys to `AppSettings.Key`, beside `enabledQuotaThresholds(for:)`.

```swift
        static func tokenMonitorVisible(for provider: AgentProvider) -> String {
            "tokenMonitor.visible.\(provider.rawValue)"
        }
        static func tokenMonitorSections(for provider: AgentProvider) -> String {
            "tokenMonitor.sections.\(provider.rawValue)"
        }
```

- [ ] **Step 3:** Add the published properties, after `enabledQuotaThresholdsByProvider`.

```swift
    /// Whether each agent contributes a token activity card. This gates
    /// collection as well as display, so it is read by `LocalActivityMonitor`
    /// and not only by the menu.
    @Published private(set) var tokenMonitorVisibilityByProvider: [AgentProvider: Bool] {
        didSet { persistTokenMonitorVisibility() }
    }
    @Published private(set) var tokenMonitorSectionsByProvider: [AgentProvider: Set<TokenMonitorSection>] {
        didSet { persistTokenMonitorSections() }
    }
```

- [ ] **Step 4:** Load them in `init`, before `persistQuotaThresholds()`. An absent key means the feature has never been touched, so it takes the everything-visible default rather than `false`.

```swift
        tokenMonitorVisibilityByProvider = Self.tokenMonitorVisibility(defaults: defaults)
        tokenMonitorSectionsByProvider = Self.tokenMonitorSections(defaults: defaults)
```

- [ ] **Step 5:** Add the loaders and persisters next to `quotaThresholdsByProvider(defaults:)`.

```swift
    private static func tokenMonitorVisibility(defaults: UserDefaults) -> [AgentProvider: Bool] {
        var result: [AgentProvider: Bool] = [:]
        for provider in AgentProvider.allCases {
            let key = Key.tokenMonitorVisible(for: provider)
            result[provider] = defaults.object(forKey: key) == nil
                ? true
                : defaults.bool(forKey: key)
        }
        return result
    }

    private static func tokenMonitorSections(defaults: UserDefaults) -> [AgentProvider: Set<TokenMonitorSection>] {
        var result: [AgentProvider: Set<TokenMonitorSection>] = [:]
        for provider in AgentProvider.allCases {
            let key = Key.tokenMonitorSections(for: provider)
            guard let stored = defaults.array(forKey: key) as? [String] else {
                result[provider] = Set(TokenMonitorSection.allCases)
                continue
            }
            // An unknown stored value is a section this build no longer has;
            // dropping it is correct and must not disable the rest.
            result[provider] = Set(stored.compactMap(TokenMonitorSection.init(rawValue:)))
        }
        return result
    }

    private func persistTokenMonitorVisibility() {
        for (provider, visible) in tokenMonitorVisibilityByProvider {
            defaults.set(visible, forKey: Key.tokenMonitorVisible(for: provider))
        }
    }

    private func persistTokenMonitorSections() {
        for (provider, sections) in tokenMonitorSectionsByProvider {
            defaults.set(sections.map(\.rawValue).sorted(), forKey: Key.tokenMonitorSections(for: provider))
        }
    }
```

- [ ] **Step 6:** Add the accessors beside `isQuotaThresholdEnabled(_:for:)`.

```swift
    func isTokenMonitorVisible(for provider: AgentProvider) -> Bool {
        tokenMonitorVisibilityByProvider[provider] ?? true
    }

    func setTokenMonitorVisible(_ visible: Bool, for provider: AgentProvider) {
        tokenMonitorVisibilityByProvider[provider] = visible
    }

    func isTokenMonitorSectionEnabled(_ section: TokenMonitorSection, for provider: AgentProvider) -> Bool {
        tokenMonitorSectionsByProvider[provider]?.contains(section) ?? true
    }

    func setTokenMonitorSection(_ section: TokenMonitorSection, enabled: Bool, for provider: AgentProvider) {
        var sections = tokenMonitorSectionsByProvider[provider] ?? Set(TokenMonitorSection.allCases)
        if enabled {
            sections.insert(section)
        } else {
            sections.remove(section)
        }
        tokenMonitorSectionsByProvider[provider] = sections
    }

    func enabledTokenMonitorSections(for provider: AgentProvider) -> Set<TokenMonitorSection> {
        tokenMonitorSectionsByProvider[provider] ?? Set(TokenMonitorSection.allCases)
    }
```

- [ ] **Step 7:** Build and run the existing suite. Nothing consumes these yet, so the only expected outcome is that nothing broke.

```bash
cd CodexUsageMonitor
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/token-monitor-settings-derived build
swift test
```

Expected: exit `0`, `** BUILD SUCCEEDED **`, 299 tests with 0 failures.

- [ ] **Step 8:** Commit as `feat: store per-agent token monitor preferences`.

---

### Task 2: Render only the enabled card sections

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityCard.swift`

**Interfaces:**

- Consumes: `TokenMonitorSection` from Task 1.
- Produces: `ProviderTokenActivityCard(presentation:visibleSections:)`.

- [ ] **Step 1:** Add the stored property. Defaulting to every section keeps existing call sites and previews honest until Task 3 passes real preferences.

```swift
    let presentation: ProviderTokenActivityPresentation
    var visibleSections: Set<TokenMonitorSection> = Set(TokenMonitorSection.allCases)
```

- [ ] **Step 2:** Replace `expandedBody(_:)` entirely. Dividers are placed between *rendered* sections, so hiding one never leaves an orphaned rule, and an already-empty section (no model groups, no observed request) still suppresses its own divider.

```swift
    private func expandedBody(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        let sections = renderableSections(expanded)

        return VStack(alignment: .leading, spacing: MenuPopoverTheme.activitySectionSpacing) {
            ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                if index > 0 {
                    Rectangle()
                        .fill(theme.divider)
                        .frame(height: MenuPopoverTheme.dividerHeight)
                }
                sectionBody(section, expanded)
            }
        }
    }

    /// A section renders when the user enabled it *and* it has something to
    /// show. Both conditions are resolved here so divider placement has one
    /// source of truth.
    private func renderableSections(
        _ expanded: ProviderTokenActivityPresentation.Expanded
    ) -> [TokenMonitorSection] {
        TokenMonitorSection.allCases.filter { section in
            guard visibleSections.contains(section) else { return false }
            switch section {
            case .activityChart, .tokenCategories:
                return true
            case .modelUsage:
                return !expanded.modelUsage.isEmpty
            case .lastRequest:
                return expanded.lastRequest != nil
            }
        }
    }

    @ViewBuilder
    private func sectionBody(
        _ section: TokenMonitorSection,
        _ expanded: ProviderTokenActivityPresentation.Expanded
    ) -> some View {
        switch section {
        case .activityChart:
            chart(expanded)
        case .tokenCategories:
            metricColumns(expanded)
        case .modelUsage:
            VStack(alignment: .leading, spacing: MenuPopoverTheme.activityRowSpacing) {
                ForEach(expanded.modelUsage) { model in
                    modelRow(model)
                }
            }
        case .lastRequest:
            if let lastRequest = expanded.lastRequest {
                lastRequestRow(lastRequest)
            }
        }
    }
```

- [ ] **Step 3:** Confirm the hover state cannot survive hiding the chart. Add this to `chart(_:)`'s enclosing `VStack` so a pointer that was over a bar when a preference changed does not leave a stale caption:

```swift
        .onDisappear { hoveredBucket = nil }
```

- [ ] **Step 4:** Build and run the full suite.

```bash
cd CodexUsageMonitor
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/token-monitor-settings-derived build
swift test
```

Expected: exit `0`, 299 tests with 0 failures. The card still renders every section, because no caller passes a reduced set yet.

- [ ] **Step 5:** Commit as `feat: render only enabled token activity sections`.

---

### Task 3: Gate the card and its collection on the master toggle

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift`

**Interfaces:**

- Consumes: `AppSettings.isTokenMonitorVisible(for:)` and `enabledTokenMonitorSections(for:)` from Task 1; `ProviderTokenActivityCard(presentation:visibleSections:)` from Task 2.
- Produces: `LocalActivityMonitor.setCollectionEnabled(_:for:)`.

- [ ] **Step 1:** Add the collection flag to `LocalActivityMonitor`, beside `isRunning`.

```swift
    /// Providers the user has chosen to see. A provider that is off is not
    /// read at all, so hiding a card is a collection decision rather than a
    /// display filter.
    private var collectionEnabled: [AgentProvider: Bool] = [:]
```

- [ ] **Step 2:** Make `start()` skip disabled providers. Replace the loop body inside `start()`:

```swift
        let cached = cache.load()
        for provider in sources.keys {
            guard collectionEnabled[provider] ?? true else { continue }
            if let requests = cached[provider] {
                reconciledRequests[provider] = requests
                publish(provider)
            } else {
                states[provider] = .loading
            }
            startObserver(for: provider)
            scheduleScan(for: provider)
        }
        observeSystemChanges()
```

- [ ] **Step 3:** Add `setCollectionEnabled(_:for:)`. It records the flag even before `start()`, because `QuotaViewModel` subscribes during its own initialization.

```swift
    func setCollectionEnabled(_ enabled: Bool, for provider: AgentProvider) {
        guard (collectionEnabled[provider] ?? true) != enabled else { return }
        collectionEnabled[provider] = enabled
        guard isRunning, sources[provider] != nil else { return }

        if enabled {
            states[provider] = .loading
            startObserver(for: provider)
            scheduleScan(for: provider)
            return
        }

        scanTasks[provider]?.cancel()
        scanTasks[provider] = nil
        rescanRequested.remove(provider)
        observers[provider]?.stop()
        observers[provider] = nil
        reconciledRequests[provider] = nil
        states[provider] = nil
        // Rewriting without this provider is what removes it from disk. A
        // provider the user hid must not leave observations behind.
        cache.save(reconciledRequests)
    }
```

- [ ] **Step 4:** Guard `scheduleScan(for:)` so a file event that arrives while a provider is being disabled cannot restart it. Add to the existing guard:

```swift
    private func scheduleScan(for provider: AgentProvider) {
        guard isRunning, collectionEnabled[provider] ?? true, let source = sources[provider] else { return }
```

- [ ] **Step 5:** Forward preference changes in `QuotaViewModel.init`, next to the existing `activityMonitor.$states` subscription.

```swift
        settings.$tokenMonitorVisibilityByProvider
            .removeDuplicates()
            .sink { [weak activityMonitor] visibility in
                guard let activityMonitor else { return }
                for provider in AgentProvider.allCases {
                    activityMonitor.setCollectionEnabled(visibility[provider] ?? true, for: provider)
                }
            }
            .store(in: &subscriptions)
```

- [ ] **Step 6:** Gate the Codex card. In `CodexMenuContent`, replace `activityCard`:

```swift
    @ViewBuilder
    private var activityCard: some View {
        if viewModel.settings.isTokenMonitorVisible(for: .codex) {
            ProviderTokenActivityCard(
                presentation: ProviderTokenActivityPresentation(
                    provider: .codex,
                    state: viewModel.localActivityState(for: .codex)
                ),
                visibleSections: viewModel.settings.enabledTokenMonitorSections(for: .codex)
            )
        }
    }
```

- [ ] **Step 7:** Make `CodexMenuContent` observe the store, so a toggle updates the open popover. Add beside the existing `@ObservedObject var viewModel`:

```swift
    @ObservedObject var settings: AppSettings
```

and pass it from `MenuBarPopoverView.providerContent`:

```swift
        case .codex:
            CodexMenuContent(viewModel: viewModel, settings: viewModel.settings)
```

- [ ] **Step 8:** Apply Steps 6 and 7 to `ClaudeMenuContent` with `.claudeCode`, and update the matching `MenuBarPopoverView` case:

```swift
    @ViewBuilder
    private var activityCard: some View {
        if settings.isTokenMonitorVisible(for: .claudeCode) {
            ProviderTokenActivityCard(
                presentation: ProviderTokenActivityPresentation(
                    provider: .claudeCode,
                    state: viewModel.localActivityState(for: .claudeCode)
                ),
                visibleSections: settings.enabledTokenMonitorSections(for: .claudeCode)
            )
        }
    }
```

```swift
        case .claudeCode:
            ClaudeMenuContent(viewModel: viewModel, settings: viewModel.settings)
```

- [ ] **Step 9:** Build and run the full suite.

```bash
cd CodexUsageMonitor
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/token-monitor-settings-derived build
swift test
```

Expected: exit `0`, 299 tests with 0 failures.

- [ ] **Step 10:** Verify the cache purge with a disposable harness under `/private/tmp`, outside the repository. It must construct a `LocalActivityCache` on a temporary file, save two providers, then confirm that disabling one and re-saving leaves only the other. Emit only counts and booleans. Delete the harness after recording its output. Do not add an XCTest for this.

- [ ] **Step 11:** Commit as `feat: hide and stop collecting an agent's token monitor`.

---

### Task 4: Add the Token Monitor section to both agent pages

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentTokenMonitorSection.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift`

**Interfaces:**

- Consumes: everything from Task 1.
- Produces: `AgentTokenMonitorSection(settings:provider:)`.

- [ ] **Step 1:** Create `AgentTokenMonitorSection.swift`. It observes `AppSettings` directly for the same reason `AgentUsageWarningsSection` does: a closure-only API leaves the controls in a subtree that does not observe the store, so a tap animates without changing state.

Note the `.disabled` placement. It goes on each sub-toggle, never on the enclosing `SettingsSection` — disabling the section would also disable the master toggle, leaving no way back on.

```swift
import SwiftUI

/// Per-agent control over the menu popover's Token Monitor card.
///
/// The master toggle is deliberately more than a display filter: turning it
/// off also stops reading that agent's local records, so the description says
/// so plainly rather than implying the app keeps watching either way.
struct AgentTokenMonitorSection: View {
    @ObservedObject var settings: AppSettings
    let provider: AgentProvider

    private var isVisible: Bool {
        settings.isTokenMonitorVisible(for: provider)
    }

    var body: some View {
        SettingsSection("Token Monitor") {
            SettingsSectionRow {
                SettingsPreferenceToggle(
                    "Show token monitor",
                    description: "Adds a Token Monitor card to \(provider.tabTitle)'s menu. Turning this off also stops reading \(provider.tabTitle)'s local records and removes what was cached for it.",
                    isOn: Binding(
                        get: { settings.isTokenMonitorVisible(for: provider) },
                        set: { settings.setTokenMonitorVisible($0, for: provider) }
                    )
                )
            }

            ForEach(Array(TokenMonitorSection.allCases.enumerated()), id: \.element) { index, section in
                SettingsSectionRow(showsDivider: index < TokenMonitorSection.allCases.count - 1) {
                    SettingsPreferenceToggle(
                        section.title,
                        description: section.settingsDescription,
                        isOn: Binding(
                            get: { settings.isTokenMonitorSectionEnabled(section, for: provider) },
                            set: { settings.setTokenMonitorSection(section, enabled: $0, for: provider) }
                        )
                    )
                    .disabled(!isVisible)
                }
            }
        }
    }
}
```

- [ ] **Step 2:** Render it in `CodexAgentSettingsView.body`, after `AgentQuotaSessionSection` and before `AgentUsageWarningsSection`, so display controls sit above notification controls.

```swift
        AgentTokenMonitorSection(settings: settings, provider: .codex)

        AgentUsageWarningsSection(settings: settings, provider: .codex)
```

- [ ] **Step 3:** Render it in `ClaudeAgentSettingsView.body` in the equivalent position. That view already declares `@ObservedObject var settings: AppSettings` and `AgentsSettingsView` already passes `viewModel.settings`, so no plumbing is needed.

```swift
        AgentTokenMonitorSection(settings: settings, provider: .claudeCode)
```

- [ ] **Step 4:** Check the width budget before accepting the layout. `SettingsLayoutMetrics.trailingControlBudget(pageWidth:layout:)` gives 235 pt at the default 499 pt compact width; a switch is far narrower, but the longest description must wrap rather than widen the card. Confirm no new constant duplicates `SettingsLayoutMetrics`.

- [ ] **Step 5:** Build and run the full suite.

```bash
cd CodexUsageMonitor
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/token-monitor-settings-derived build
swift test
```

Expected: exit `0`, 299 tests with 0 failures.

- [ ] **Step 6:** Commit as `feat: add a per-agent Token Monitor settings section`.

---

### Task 5: Adopt the Token Monitor name and correct the privacy documentation

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityPresentation.swift`
- Modify: `CONTEXT.md`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-07-14-dashboard.md`

- [ ] **Step 1:** Rename the card header so Settings and the menu agree. In `ProviderTokenActivityPresentation`:

```swift
    static let title = "Token Monitor"
```

Leave the surrounding type names alone. `ProviderTokenActivityCard`, `ProviderTokenActivityPresentation`, `LocalActivityMonitor`, and the `Activity/` directory are internal identifiers; the vocabulary rule governs what a user reads, and renaming them would add churn and review surface for no user-visible gain. Add a line to the type's doc comment recording that the name shown is Token Monitor, so the mismatch reads as a decision rather than an oversight.

- [ ] **Step 2:** Add the terms to `CONTEXT.md` under **Local Token Activity**, so the Settings name and the card name cannot drift apart again.

```markdown
**Token Monitor**:
The menu-popover card showing token usage observed from an agent's local records on this Mac. It supersedes the earlier names Dashboard and Token Activity; those must not appear in user-facing copy.
_Avoid_: Dashboard, Token Activity, usage graph

**Token Monitor Visibility**:
The per-agent preference that decides whether that agent contributes a Token Monitor card. Turning it off also stops reading that agent's local records and discards its cached observations; it is not a display filter.
_Avoid_: Hide card, disable activity, pause monitoring

**Token Monitor Section**:
One toggleable region of the Token Monitor card — Activity chart, Token categories, Model usage, or Last request. Section toggles change only what is rendered; every section is derived from the same reconciled request set.
_Avoid_: Card row, widget, module
```

- [ ] **Step 3:** Update the Token Monitor block in `DataPrivacySettingsView` so the "Local records" row stops implying reading is unconditional.

```swift
                SettingsSectionRow {
                    SettingsValueRow(
                        "Local records",
                        value: "Read automatically",
                        description: "For each agent whose Token Monitor is shown, this app reads the session records that agent already writes on this Mac, so the menu can show tokens observed today. This starts on its own, keeps working when an agent is disconnected, makes no network request, and costs no tokens. Turning an agent's Token Monitor off in Agents stops reading that agent's records and removes what was cached for it."
                    )
                }
```

- [ ] **Step 4:** In `how-to.md`, describe the control where the card is described: each agent's Settings page has a **Token Monitor** section with a show/hide toggle and four section toggles; hiding an agent's Token Monitor stops reading that agent's records; the card's title, scope, day total, and request count always remain when it is shown. Replace any remaining "Token activity" phrasing with **Token Monitor**.

- [ ] **Step 5:** In `outline.md` and `UsageProbe/README.md`, rename the feature to **Token Monitor** and add one sentence each stating that visibility and section composition are per-agent preferences, and that hiding an agent stops collection for it.

- [ ] **Step 6:** In `docs/superpowers/plans/2026-07-14-dashboard.md`, record the rename and add a short subsection under the Task 6 Step 4 gate carrying the measured saving for each hidden section from Task 6. State explicitly that the height problem is deferred and tracked on the Bug-fix board, and that a default install is unchanged at 929 points so this feature does not close it.

- [ ] **Step 7:** In `docs/product/planning-board.md`, update the queued Feature board row for this work, and add the measured per-section savings to the deferred Bug-fix row *Token Monitor card makes the popover taller than a laptop screen*.

- [ ] **Step 8:** Commit as `docs: adopt the Token Monitor name and document visibility`.

---

### Task 6: Verify preferences, geometry, and the signed app

**Files:**

- Modify: `docs/superpowers/plans/2026-07-28-agent-dashboard-settings.md` with dated evidence only.

- [ ] **Step 1:** Run the required build and the full suite from `CodexUsageMonitor`.

```bash
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/token-monitor-settings-derived build
swift test
```

Expected: exit `0`, `** BUILD SUCCEEDED **`, 299 tests with 0 failures. Record warnings precisely; the pre-existing `kSecUseAuthenticationUIFail` deprecations are unrelated.

- [ ] **Step 2:** Measure every section combination with a disposable `NSHostingView` harness at the 308-point popover content width, following the pattern used for the earlier token activity measurements. Record the card height with all sections on, with each single section off, and with all four off. Assert no combination exceeds 308 points wide. Delete the harness afterwards; do not add an XCTest.

- [ ] **Step 3:** Recompute the tallest Codex tab for the default configuration and for the shortest useful configuration, using the measured chrome values: tab strip 44, provider header 58, shared gap 12, action footer 137. Confirm the default is unchanged at approximately 929 points and record what the smallest configuration achieves.

- [ ] **Step 4:** Confirm the preference round trip against a scratch `UserDefaults` suite in a disposable harness: an unset key reads as visible with all sections enabled; a stored unknown section string is dropped without disabling the others; and a provider disabled and re-enabled returns to its stored section set. Emit only booleans. Delete the harness.

- [ ] **Step 5:** Confirm collection actually stops. With the signed app running and the Codex Token Monitor hidden, verify that `token-activity-cache.json` no longer contains a Codex entry, that no Codex scan is scheduled by a file write under `~/.codex/sessions`, and that re-enabling repopulates both. Record only presence booleans and counts — never a path, session identifier, or record content.

- [ ] **Step 6:** Build and verify the signed app.

```bash
bash Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app
```

- [ ] **Step 7:** Perform the Settings visual acceptance AGENTS.md requires. Open the signed app's Settings at the default 680 × 560 size and inspect the Agents destination for both agents, with the Context Rail hidden and visible, in Light and Dark. Check for leading-label clipping, descriptions running under the switches, controls past the trailing edge, unreachable content at the bottom, and consistent section spacing against the neighbouring Connection and Remaining Quota sections. Confirm the sub-toggles visibly dim when the master toggle is off and that the master toggle itself stays operable.

- [ ] **Step 8:** Perform the popover acceptance. With the menu open, toggle each section and confirm the card updates with at most one host resize per change, that dividers never appear above or below nothing, that hiding the chart clears any hover caption, and that hiding the Token Monitor removes the card without leaving a gap above the footer. Repeat for both providers and across a provider switch.

- [ ] **Step 9:** Verify keyboard and VoiceOver traversal of the new Settings rows, and confirm the card's remaining sections still expose their exact values.

- [ ] **Step 10:** Record any check that could not be performed as **unobserved**, never as passed. Compilation and source inspection are not visual acceptance.

- [ ] **Step 11:** Commit as `docs: record token monitor settings verification evidence`.

---

## Explicitly Deferred

- A global "hide every Token Monitor" preference. Per-agent control covers the need; a global switch would have to be migrated if agents ever diverge.
- Reordering card sections, or per-agent choice of which token categories appear within Token categories.
- A separate preference for the request count or the day total. The card's header is its identity and stays.
- Per-agent retention or scan-frequency controls.
- Restoring collection for a hidden agent in the background so re-enabling is instant. Re-reading from scratch is the honest behavior and matches the stated privacy boundary.
- Any change to the reconciliation sources, the monitor's incremental scanning, or the activity cache format.

## Completion Criteria

- Each supported agent's Settings page has a **Token Monitor** section with one master toggle and four section toggles, built from the shared Settings components.
- Defaults are unchanged behavior: visible, all sections enabled, for every supported provider on a first launch after the change.
- Hiding an agent's Token Monitor removes its card from the menu, stops its observer and scans, clears its in-memory requests, and removes its entry from `token-activity-cache.json`.
- Section toggles change only rendering. Dividers appear only between rendered sections, and an empty Model usage or absent Last request suppresses its own divider.
- The card always shows its title, **This Mac · observed**, the day's total, and the request count whenever it is shown at all.
- Sub-toggles are disabled while the master toggle is off, and the master toggle remains operable.
- `xcodebuild`, the full existing suite, the signed-app build and signature, the disposable preference and geometry harnesses, and the required Settings and popover visual acceptance all have recorded evidence — with anything unobserved recorded as such.

## Self-Review

- **Requested surface:** a Settings section named Token Monitor inside Agents, a per-agent show/hide toggle, and several toggles for what the card shows. All four section toggles map to a region a user can actually point at in the card.
- **Naming:** **Token Monitor** was chosen on direction and is applied to every user-facing surface, including the existing card header, so one feature carries one name. Internal type names are deliberately left alone and that choice is recorded rather than left to look like an oversight.
- **Scope discipline:** no change to reconciliation, the monitor's incremental scanning, or the cache format. The only behavioral change outside Settings is that a hidden provider is not read.
- **Privacy:** hiding is a collection decision, not a display filter, and the cache is purged rather than orphaned. The Data & Privacy copy is corrected in the same change rather than left describing unconditional reading.
- **Repository test policy:** no feature-presence or toggle round-trip tests are added. Verification uses disposable harnesses, the existing suite, builds, and signed-app acceptance, with a regression test reserved for a reproducible defect.
- **Honest limits:** the popover height problem is deferred by direction and tracked on the Bug-fix board. This plan states plainly that it does not fix it and that a default install is unchanged, rather than letting the section toggles read as a resolution.
