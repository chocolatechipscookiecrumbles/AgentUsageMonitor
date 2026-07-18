# Settings and Multi-Agent Follow-ups Implementation Plan

**Recovered status (2026-07-18):** the UI-only fixed-geometry and native-switch subset of Task 1 was implemented by the dedicated [Figma Settings Design Completion plan](2026-07-17-figma-settings-design-completion.md). Fresh package and signed-bundle checks passed, but its required direct Settings-window acceptance remains manual. Tasks 2–7 remain deferred and require revalidation against current `main`, supported-provider capabilities, repository `AGENTS.md`, and the evidence-rich PR guidance before implementation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Add focused automated coverage for deterministic state, migration, and policy seams; verify native presentation separately with warnings-as-errors compilation, a signed-app inspection, and controlled notification/connection acceptance.

**Goal:** Extend the Figma Settings shell with fixed Navigation Sidebar and Settings Page geometry, indexed setting search, native switch styling, independent quota-warning scopes, provider-identified notifications, app-local agent disconnection, and provider-aware Agents navigation.

**Architecture:** Keep `SettingsView` as the owner of global navigation, selected Settings Destination, Settings Agent, search routing, and Context Rail visibility. Keep Preferred Menu Bar Agent selection independent. Add provider-and-quota-window scope to notification preferences without changing the current Codex collector contract, and introduce an app-local provider enrollment state so Disconnect stops this app from monitoring an agent without deleting credentials owned by the provider. Provider selectors and status cards must derive from real Supported/Active/Connected Agents rather than `AgentProvider.allCases` or hard-coded planned entries.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit semantic colors, UserNotifications, Combine, UserDefaults-backed `AppSettings`, native controls, SF Symbols, and the existing signed SwiftPM app bundle.

## Global Constraints

- This document records future work only. Do not treat any checkbox as implemented until the Swift change and its acceptance evidence exist.
- Preserve the existing collector, scheduling, notification-episode, privacy, and confirmed-versus-cached contracts.
- Keep Refresh Outcome and Refresh Failure Classification as separate typed dimensions. Before implementing new cause categories, write a dedicated reliability plan that audits collector errors, macOS network-path evidence, provider compatibility signals, persistence, and user-facing copy.
- Keep Codex as the only supported provider until the separate Claude or GitHub capability and provider plans are completed.
- Do not show provider-specific controls for a planned provider that cannot yet supply the required connection or quota state.
- Keep the fixed quota thresholds at 50%, 25%, 10%, and 5%; this work changes their scope, not their values.
- Use native SwiftUI switch toggles and system colors. Do not introduce custom checkbox artwork or a web runtime.
- Every new control and state must follow the existing Settings Design Language: shared layout metrics, semantic system colors, system typography, grouped cards, SF Symbols, and native macOS interaction behavior.
- The July 14 user-provided Agent Selector images are structural interaction references only. Their provider icons, brand colors, background values, dimensions, and provider list are not approved assets or final tokens; write a separate Agent Selector visual plan before implementing Task 6.
- Use a Preference Switch for every independent Boolean preference. Reserve checkboxes for future batch-selection semantics; no current Settings preference requires a checkbox.
- Keep the Navigation Sidebar unchanged and keep the Settings Page at one constant measured frame when the Context Rail changes between Hidden and Visible. The Context Rail must not stretch, compress, or shift either left-hand region.
- Search must use a static Settings Search Index containing every actionable or settable control across all Settings Destinations; it must not scrape rendered SwiftUI text or index read-only Context Rail/status content.
- A provider Disconnect action must be reversible and scoped to this app by default. It must not invoke `codex logout`, delete provider credentials, edit `~/.codex`, or sign the user out of another provider client without a separately approved destructive sign-out feature.
- A macOS notification may use the application icon when the system does not support a reliable per-notification provider icon. In that fallback, the provider and quota window must be explicit in the title and message.

## Product Decisions Recorded for Implementation

1. **Quota warning scope:** five-hour and weekly Window Warning Settings are independent. Each window owns its thresholds, forecasted-exhaustion preference, and reset/reset-failure preference. The current combined Codex values migrate into both scopes so an upgrade preserves current delivery behavior.
2. **Future providers:** per-agent warning groups appear only after that provider is implemented and only for quota windows it actually exposes. Do not assume every provider has Codex's five-hour and weekly model.
3. **Disconnect meaning:** Disconnect removes the agent's app-local link, monitoring, and notifications. It does not log out, revoke, edit, or delete the provider-owned Provider Session; reconnect may reuse that session without another sign-in.
4. **Notification identity:** the minimum accepted design is the Codex Usage Monitor application icon plus provider-specific title/body copy. A ChatGPT/Codex, Anthropic, or GitHub brand mark may be added only if an approved asset exists and signed macOS notification testing proves it is rendered reliably.
5. **Agents navigation:** the Agents destination header becomes an agent selector. The middle page shows only the selected supported agent, while the right rail shows one status block for every currently active or connected agent.
6. **Region geometry:** the Navigation Sidebar remains in its current full search-and-destination form. Only the Context Rail changes between Hidden and Visible, and that visibility change does not alter the Navigation Sidebar or Settings Page frames.
7. **Default visibility:** the Context Rail is Hidden when the Settings Window first opens, making the two-region window the default presentation.
8. **Visibility lifetime:** Context Rail visibility is presentation-only state for the currently open Settings Window. Do not persist it in `AppSettings`, `UserDefaults`, or another relaunch store.
9. **Toggle placement:** the Context Rail Toggle remains at the trailing edge of the Settings Page Header in both visibility states. It does not move into the macOS title bar or the Context Rail.
10. **Quota selector lifetime:** the Quota Window Selector defaults to 5-Hour, retains its selection while the current Settings Window remains open, and is not persisted across a new Settings Window or app relaunch.
11. **Warning location:** Window Warning Settings live on the selected Agent Settings Page in the Agents Settings Destination. Notifications owns authorization, the master switch, Global Warnings, and a navigation link to agent usage warnings; it does not add a second Agent Selector.
12. **Search focus:** Settings uses Search-First Focus. Search is ready when the window opens and after result navigation; unmodified printable typing starts a query when no control or text-capture interaction owns the keystroke. Command shortcuts remain unaffected.
13. **Search architecture:** search queries a static Settings Search Index, not the live SwiftUI hierarchy. Each Searchable Setting owns stable control/destination/section identities, title, synonyms, and keywords; read-only status and Context Rail content are excluded. See ADR `docs/adr/0001-index-settings-search-metadata.md`.
14. **Agent selections:** Settings Agent and Preferred Menu Bar Agent are independent selections. Browsing or editing an Agent Settings Page must not change which agent appears in the menu bar.
15. **Menu Bar Agent eligibility:** the Menu Bar Agent Selector contains Connected Agents even when their monitoring is inactive. An inactive Effective Menu Bar Agent remains visible using the Paused Menu Bar State.
16. **Menu Bar settings ownership:** add the Menu Bar Agent Selector to General's existing Menu Bar section initially. When future icon/display options are approved, move the entire Menu Bar section into a dedicated Menu Bar Settings Destination rather than continuing to grow General.
17. **Menu Bar connection loss:** expose a persisted Menu Bar Failover Policy instead of hard-coding fallback. **Stay Selected** is the default and keeps the chosen agent while rendering its disconnected/unavailable state; **Switch Automatically** chooses another Connected Agent when available. If no agent is connected, both policies keep the current identity and show disconnection.
18. **Failover scope:** Menu Bar Failover Policy applies only to Single-Agent Menu Bar Mode. Preserve a Preferred Menu Bar Agent separately from the Effective Menu Bar Agent; automatic fallback is temporary and returns to the preferred agent when it reconnects. A future Multi-Agent Menu Bar Mode defines its own fallback and does not inherit this rule.
19. **Multi-agent control state:** provisionally keep Preferred Menu Bar Agent and Menu Bar Failover Policy visible but disabled in Multi-Agent Menu Bar Mode, with explanatory text and stored values preserved. A later approved Multi-Agent design may simplify this presentation but must not silently delete the single-agent values.
20. **Agents Context Rail eligibility:** render one Agent Status Block for every Paired Agent—any Supported Agent that completed pairing at least once—including active, inactive, connected, and disconnected states. Never-paired providers do not appear in the Context Rail.
21. **Pairing retention:** retain Paired Agent history and its Agent Status Block indefinitely in this phase. Disconnect does not forget the agent, and no Forget Agent action is included.
22. **Agent Selector eligibility:** list every Supported Agent in the Agents header's Agent Selector so never-paired agents remain reachable for setup. Context Rail eligibility remains narrower: Paired Agents only.
23. **Agent ordering:** sort Supported Agent selector entries alphabetically. Keep Paired Agent Status Blocks alphabetical while they fit without vertical scrolling; when they overflow, promote the Settings Agent to the top and keep all remaining blocks alphabetical. Connection, active, and pairing transitions do not otherwise reorder them.
24. **Agent Selector presentation:** use a horizontally scrollable, icon-leading row as the primary Agent Selector, with subtle item separators, a non-color-only active underline, left/right keyboard navigation, Enter/Space selection, and an overflow affordance. A compact menu-style picker is only a fallback for accessibility or an extremely narrow layout. Reference-image colors and icons are non-final.
25. **Settings Agent lifetime:** remember Settings Agent only for the current Settings Window. Each newly opened window selects the first Supported Agent alphabetically, and the choice is never persisted in `AppSettings` or `UserDefaults`.
26. **Usage notification identity:** the guaranteed baseline is the Codex Usage Monitor application icon plus provider and Quota Window named in notification copy. Provider-specific artwork is deferred until official assets and signed macOS rendering are validated.
27. **Warning value semantics:** usage notifications always state remaining quota because their thresholds are defined as remaining percentages. Menu-bar Remaining/Used presentation does not alter warning titles, bodies, or threshold meaning.
28. **Global Warning scope:** configure each Global Warning once for the app, but evaluate transitions, provider identity, episode ownership, and delivery deduplication separately per agent.
29. **Interruption coalescing:** keep provider interruption episodes and durable keys separate, but combine alert-eligible deliveries occurring within five seconds into one Coalesced Interruption Notice that names every affected agent. Five seconds is provisional under shared refresh cadence and must be revisited before per-agent scheduling ships.
30. **Initial scheduling:** all Active Agents use one Shared Refresh Cadence configured in Refresh. Per-agent refresh-frequency controls and independent cadence are deferred.
31. **Provider refresh isolation:** each Shared Refresh Cadence cycle launches Active Agent refreshes independently in parallel. One slow, unavailable, or unconfirmed provider cannot block another provider's confirmed state, history, notification policy, or completion.
32. **Refresh diagnosis boundary:** Refresh Outcome records what trust state resulted; Refresh Failure Classification records the best supported cause. The separation is accepted in ADR `docs/adr/0002-separate-refresh-outcome-from-failure-classification.md`, while the exact cause taxonomy remains deferred to a separate reliability plan.
33. **Context Rail overflow ordering:** use actual vertical overflow, not a fixed provider count, to trigger Settings Agent promotion. Reordering does not make Agent Status Blocks interactive and must respect Reduce Motion.

---

### Task 1: Stabilize Settings region geometry and switch styling

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift` if the SwiftUI Settings scene needs explicit window-width coordination.
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsWindowSizing.swift` only if the scene cannot preserve the left edge using native SwiftUI sizing alone.
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreferenceToggle.swift`

**Interfaces:**
- Consumes: `SettingsLayoutMetrics`, `SettingsView.isPreviewVisible`, and existing `Binding<Bool>` preferences.
- Produces: named Context-Rail-Hidden and Context-Rail-Visible window widths, one constant Settings Page frame, and `SettingsPreferenceToggle(title:isOn:)`, backed by native `Toggle` with `.toggleStyle(.switch)`.

- [ ] Add one Settings Page frame metric based on the current Context-Rail-Visible layout and remove the page's `maxWidth: .infinity` stretching behavior.
- [ ] Initialize the Context Rail as Hidden so the Settings Window opens at the smaller two-region width.
- [ ] Keep Context Rail visibility as window-local presentation state; closing and reopening Settings must return it to Hidden.
- [ ] Keep the Context Rail Toggle at one stable Settings Page Header position while the Settings Window changes width.
- [ ] Preserve the Navigation Sidebar's current width, search field, destination labels, and position in both Context Rail visibility states.
- [ ] Keep the same Settings Page frame when the Context Rail is Visible and Hidden; do not replace the freed rail width by widening cards or controls.
- [ ] When the Context Rail becomes Visible, widen the Settings Window only to the right by the rail allocation. When it becomes Hidden, shrink the right edge by the same amount while preserving the window's left edge and the two left-hand region frames.
- [ ] Convert every current independent Boolean preference—Launch at Login, keyboard shortcuts, the notification master and category controls, each 50/25/10/5 threshold, and Other Warnings—to the shared native Preference Switch component.
- [ ] Keep pickers, action buttons, permission recovery, and Disconnect actions as their existing native control types; they are not Boolean switches.
- [ ] Inspect all six destinations and measure the window edge, Navigation Sidebar, and Settings Page before and after each Context Rail visibility change. Acceptance requires a stable left window edge, identical left-region origins and widths, a right-edge delta equal to the Context Rail allocation, reachable long pages, and no rail covering an interactive Settings Page control.

### Task 2: Add indexed setting search and exact-control routing

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsNavigationSidebar.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSearchTarget.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSearchIndex.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSearchMatcher.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsSearchFocusCoordinator.swift` if native SwiftUI focus and key handling cannot express the behavior without duplication.

**Interfaces:**
- Produces: `SettingsSearchIndex`, `SearchableSetting`, ranked `SettingsSearchMatch`, `SettingsSearchTarget(destination:section:setting:)`, and stable identifiers for each indexed destination, section, and control.

```swift
struct SearchableSetting: Identifiable, Hashable {
    let id: SettingsControlID
    let title: String
    let synonyms: [String]
    let destination: SettingsTab
    let section: SettingsSectionID
    let keywords: [String]
}

struct SettingsSearchMatch: Identifiable {
    let setting: SearchableSetting
    let score: Int
    let matchedText: String

    var id: SettingsControlID { setting.id }
}
```

- [ ] Build the Settings Search Index as static metadata rather than reading the rendered view hierarchy. Include one entry for every actionable or settable control in General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics.
- [ ] Include the setting title, Settings Destination, Settings Section, synonyms, and curated intent keywords in each entry. Compose future provider entries from declared provider capabilities rather than from visible rows.
- [ ] Exclude Context Rail previews, quota percentages, timestamps, connection summaries, diagnostic counts, and other read-only status displays.
- [ ] Inventory current actionable controls, including settings, permission-recovery buttons, Refresh Now, connect/Disconnect actions, the Quota Window Selector, and Window/Global Warning Preference Switches.
- [ ] Treat every Settings Search Result as navigation-only. A result may focus an Action Control but must never execute Refresh Now, open another application, connect, disconnect, or mutate a preference.
- [ ] Focus search when the Settings Window opens and restore Search-First Focus after a Settings Search Result completes navigation.
- [ ] Route unmodified printable typing into search when no active switch, picker, button, text field, or future hotkey recorder owns the interaction.
- [ ] Preserve command and modified-key behavior, including `Command-R`; modified shortcuts must not insert characters into the query.
- [ ] When a query is non-empty, make `Escape` clear it, restore the normal Navigation Sidebar list, and retain Search-First Focus. When the query is already empty, make `Escape` a no-op.
- [ ] Debounce queries for approximately 150–200 milliseconds before scoring the small static index.
- [ ] Rank case-insensitive title prefix matches above title substring matches, then synonyms, then keywords; break equal scores alphabetically by setting title.
- [ ] Add built-in edit-distance fuzzy matching only as a fallback when the normalized query has at least four characters and no stronger title, synonym, or keyword match exists. Do not add a third-party search dependency.
- [ ] While the query is active, replace normal Navigation Sidebar destinations with a flat Settings Search Results list grouped by parent Settings Destination.
- [ ] Show the setting title as the primary label and its Settings Destination as the secondary label; emphasize the substring or metadata term that explains the match.
- [ ] For zero matches, show `No results for “<query>”` rather than a blank Navigation Sidebar.
- [ ] Selecting a result must select its Settings Destination and scroll the exact actionable control into view using stable section and control identifiers.
- [ ] Animate the scroll with an ease-out duration of approximately 200 milliseconds, then apply an accent-tinted outline or background to the exact control row that fades over approximately 700 milliseconds. Do not bounce, scale, repeat, or create a persistent selection state.
- [ ] Support selecting another result in the already-open destination; routing must not depend on a tab change to trigger scrolling.
- [ ] Clear the query after a result is chosen and restore the normal Navigation Sidebar destination list.
- [ ] Respect Reduce Motion by replacing the animated scroll with an immediate jump and the fade with a brief non-moving static emphasis.
- [ ] Verify title prefix/substring, synonym, keyword, and conservative fuzzy ranking—including `lanch` → Launch at login—plus debounce behavior, grouped keyboard selection, matched-term emphasis, VoiceOver labels, the quoted zero-result message, the Setting Focus Cue, and no Settings Page geometry change while results appear.

### Task 3: Split quota warning preferences by window and provider

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/RemainingQuotaThreshold.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsContextView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationDeliveryBatcher.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaWarningScope.swift`

**Interfaces:**

```swift
enum QuotaWindowKind: String, Codable, Hashable, Sendable {
    case fiveHour = "five-hour"
    case weekly
}

struct QuotaWarningScope: Codable, Hashable, Sendable {
    let provider: AgentProvider
    let window: QuotaWindowKind
}

struct WindowWarningSettings: Codable, Equatable, Sendable {
    var enabledThresholds: Set<RemainingQuotaThreshold>
    var forecastedExhaustionEnabled: Bool
    var resetWarningEnabled: Bool
}
```

- Replace the combined lookup with provider/window-scoped threshold, forecast, and reset accessors backed by `WindowWarningSettings`.
- Store the new map under a versioned key such as `notification.quotaThresholds.v2`; do not overload the existing array format.

- [ ] On first migration, copy the legacy Codex threshold, forecasted-exhaustion, and reset-warning values into both `.codex/.fiveHour` and `.codex/.weekly`, then persist the versioned representation.
- [ ] On a fresh install, enable 50%, 25%, 10%, and 5% plus the current default forecast/reset choices for both Codex windows.
- [ ] On the selected Agent Settings Page, add one **Usage Warnings** Settings Section with a native segmented **Quota Window Selector** for **5-Hour** and **Weekly**; show only the selected window's independent Preference Switches inside the section.
- [ ] Style the Quota Window Selector using the existing Settings Design Language and shared metrics; do not add custom segment artwork, hard-coded theme colors, or web-derived styling.
- [ ] Default the Quota Window Selector to **5-Hour**, retain the selection while navigating within the current Settings Window, and do not store it in `AppSettings` or `UserDefaults`.
- [ ] Keep notification authorization, the master notification switch, reset-credit expiration, stale data, and extended update interruption in the Notifications Settings Destination under **Notifications** and **Global Warnings**.
- [ ] Apply each Global Warning Preference Switch across the app while keeping event evaluation, interruption episodes, provider identity, and delivery deduplication separate for every agent.
- [ ] Add a **Manage agent usage warnings…** navigation link in Notifications that opens the Agents Settings Destination at the selected agent's Usage Warnings section.
- [ ] Gate delivery with the exact provider/window scope; disabling a five-hour threshold must not suppress or enable the same weekly threshold.
- [ ] Apply that same exact-scope rule to forecasted exhaustion and reset/reset-failure delivery.
- [ ] Include provider, window, reset identity, and threshold in every durable delivery key so providers and windows cannot deduplicate each other accidentally.
- [ ] When another provider is implemented, derive its Agent Settings Page warning groups from real supported quota-window capabilities. Do not render empty Codex-shaped groups for providers with different limits.
- [ ] Verify migration using an isolated `UserDefaults` suite, relaunch persistence, thresholds/forecast/reset combinations in both windows, Global Warning independence, and no notification from cached or unconfirmed data.

### Task 4: Identify the provider in usage notifications

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`
- Modify: `CodexUsageMonitor/Resources/Info.plist` only if a validated notification category or approved bundled asset requires it.
- Modify: `CodexUsageMonitor/Scripts/build-app.sh` only if an approved icon asset must be copied into the signed bundle.

**Interfaces:**
- Extend `NotificationEvent` with `provider: AgentProvider` and, for quota events, `window: QuotaWindowKind?`.
- Use provider-specific thread/category identifiers for grouping while keeping the existing stable episode and delivery-deduplication rules.
- A delivery batcher may group only alert-eligible interruption events for presentation; it must not merge their provider-owned episode state or stable deduplication identities.

- [ ] Use explicit copy such as **Codex 5-hour usage is low** and **10% remains before the Codex 5-hour limit resets**; equivalent future Claude/GitHub notices must name that provider and its actual quota window.
- [ ] Keep all threshold notification copy in remaining-quota terms regardless of the independent menu-bar Remaining/Used preference.
- [ ] Keep the normal application icon as the required fallback because macOS owns the banner's application-icon slot.
- [ ] Treat application-icon-plus-provider/window copy as the shippable baseline, not as a degraded error state.
- [ ] Investigate provider artwork only with official, approved assets. Do not relabel the app icon, scrape website images, or treat a notification attachment as a guaranteed replacement for the application icon.
- [ ] If a provider image is bundled, verify it in signed Light and Dark notifications on the minimum supported macOS version. If it does not render consistently, remove it and retain the application-icon-plus-copy design.
- [ ] Verify provider and window identity in threshold, forecast, reset, stale-data, and interruption notifications without weakening the notification episode guardrails.
- [ ] Build interruption copy from typed Refresh Failure Classification and remain cautious: never label a notice as a network outage or provider compatibility change from timeout/invalid-response text alone.
- [ ] Coalesce interruption events that become alert-eligible within five seconds into one notice listing affected agents alphabetically.
- [ ] Document the five-second window as dependent on shared refresh cadence; do not reuse it unchanged if a future provider adopts independent scheduling.
- [ ] Mark every included provider event delivered only after the combined notification is successfully submitted; a failed submission leaves every provider event retryable under its original stable key.

### Task 5: Add reversible app-local Disconnect per supported agent

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Modify: future provider connection controllers only after those providers exist.

**Interfaces:**
- Persist an app-linked/enrolled-provider set in `AppSettings`; this is app state, not Provider Session or credential storage.
- Add `disconnect(_ provider: AgentProvider)` and `connect(_ provider: AgentProvider)` at the view-model boundary.
- Add a monitor stop/suspend path that cancels active work, timers, wake observers, and scheduled notifications for the disconnected provider.

- [ ] Show **Disconnect** only for a supported agent that this app currently considers connected/enrolled.
- [ ] Make Disconnect execute immediately when clicked, without a confirmation dialog. Explain in the surrounding Connection copy that it removes the agent from Codex Usage Monitor and stops monitoring/notifications but does not sign the provider out of its CLI or official application.
- [ ] After the click, stop collection, scheduling, and new usage notifications for that provider and show it as disconnected in Settings and the menu.
- [ ] Keep the disconnected provider as the Settings Agent, update the current Agent Settings Page in place, and expose Connect immediately; do not navigate to another agent automatically.
- [ ] Preserve local historical data unless the user separately invokes a future data-deletion feature.
- [ ] Offer a reconnect action. When the Provider Session still exists, reconnect reuses it without requiring another login; otherwise it enters the existing provider sign-in flow.
- [ ] Do not add Disconnect for Claude or GitHub until their real connection controllers can honor the same lifecycle contract.
- [ ] Apply the existing Refresh preference as one Shared Refresh Cadence across every Active Agent; do not add per-agent frequency controls in this phase.
- [ ] Launch each Active Agent refresh independently in parallel within the shared cycle and publish its outcome as it completes; do not wait for one provider before accepting another provider's result.
- [ ] Verify disconnect during idle, refresh, backoff, and relaunch; reconnect; provider CLI remains signed in; no refresh or warning occurs while app-disconnected.

### Task 6: Replace the Agents title with a supported-agent selector

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift`

**Interfaces:**
- `SettingsView` owns `settingsAgent` alongside the selected Settings Destination and Context Rail visibility. Preferred Menu Bar Agent is a separate app preference consumed by menu presentation.
- A provider registry exposes Supported Agents, Paired Agents, and current per-provider connection/active state. It must not use all planned enum cases as proof of support.
- A separate Agent Selector visual plan must approve final icon sources, semantic color tokens, exact metrics, overflow treatment, and signed Light/Dark behavior before this task is implemented.

- [ ] For non-Agents destinations, keep the normal page title. For Agents, replace the **Agents** header text with the horizontal Agent Selector listing Supported Agents.
- [ ] Render each Agent Selector item with a leading approved icon, one-line provider name, subtle separator, and active underline; do not copy the unofficial reference-image icons or brand colors into production.
- [ ] Scroll horizontally when all Supported Agents do not fit, expose a clear overflow affordance, and keep the Settings Page frame unchanged.
- [ ] Support left/right arrow navigation and Enter/Space selection, maintain a non-color-only active indicator, and provide a menu-style fallback only when the primary row cannot remain accessible.
- [ ] Initially list only OpenAI Codex. Claude Code and GitHub Copilot join automatically when their adapters declare actual support, even before a user pairs them.
- [ ] Sort Agent Selector entries alphabetically by displayed provider name using locale-aware comparison. Keep Agent Status Blocks alphabetical while they fit; on actual vertical overflow, promote Settings Agent and keep the rest alphabetical.
- [ ] Default Settings Agent to the first Supported Agent alphabetically for each newly opened Settings Window, retain it only for that window session, and do not persist it.
- [ ] Render only the Settings Agent's Agent Settings Page—connection, quota status, privacy, connect/Disconnect actions, and Window Warning Settings—in the center region; remove the current stack of planned-provider sections from the active UI.
- [ ] In the Context Rail, render one Agent Status Block per Paired Agent, including icon, provider name, active state, connection state, and provider-specific quota status when available.
- [ ] Keep Agent Status Blocks read-only. Clicking or focusing a block must not change Settings Agent; all agent switching occurs through the Agent Selector.
- [ ] Animate Settings Agent block promotion only when overflow ordering changes, using a non-spring ease-in-out transition of approximately 200 milliseconds with no opacity flash or scaling; under Reduce Motion, apply the final order immediately without movement.
- [ ] Keep inactive and disconnected Paired Agents in the Context Rail with their current state represented accurately; exclude only Supported Agents that have never completed pairing.
- [ ] Persist Paired Agent history across Disconnect and relaunch. Do not add a Forget Agent or status-block removal action in this phase.
- [ ] If the Settings Agent becomes unsupported or unavailable, choose the first Supported Agent deterministically and announce the change accessibly.
- [ ] Changing the Settings Agent must not mutate the independent Preferred Menu Bar Agent preference or immediately change the menu-bar icon/label.
- [ ] Verify one-, two-, and three-provider layouts; selection persistence for the lifetime of the Settings window; disconnect/reconnect transitions; narrow/long labels; Context Rail visibility changes; and constant Navigation Sidebar and Settings Page geometry.

### Task 7: Add Menu Bar Agent selection and preserve the extraction boundary

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/MenuBarAgentSelector.swift`
- Future move when icon/display options expand: modify `SettingsTab.swift`, `SettingsDetailView.swift`, `SettingsPreviewView.swift`, and `SettingsSearchIndex.swift`; create `MenuBarSettingsView.swift`.

**Interfaces:**
- Persist `preferredMenuBarAgent: AgentProvider` independently from `settingsAgent`.
- Persist `menuBarFailoverPolicy` with `staySelected` and `switchAutomatically` choices.
- The selector consumes Connected Agents, not Active Agents.
- Single-agent menu presentation derives an Effective Menu Bar Agent from the preferred agent, failover policy, current connections, and monitoring-active state.

- [ ] Add a native Menu Bar Agent Selector to **General → Menu Bar** and include only Connected Agents.
- [ ] Add a native Menu Bar Failover Policy control with **Stay Selected** and **Switch Automatically** choices, defaulting fresh installs and migration to Stay Selected; do not present this two-choice policy as a Boolean Preference Switch.
- [ ] Keep connected-but-inactive agents selectable and render the existing pause symbol before their statistics using the Paused Menu Bar State.
- [ ] Under Stay Selected, preserve the Menu Bar Agent through connection loss and render its disconnected/unavailable state. Under Switch Automatically, choose the first remaining Connected Agent deterministically; if none exists, preserve the current identity and render disconnection.
- [ ] Under Switch Automatically, keep fallback temporary: do not overwrite Preferred Menu Bar Agent, expose the fallback only as Effective Menu Bar Agent, and return to the preferred agent when it reconnects.
- [ ] Apply Menu Bar Failover Policy only in Single-Agent Menu Bar Mode. A future Multi-Agent Menu Bar Mode must define its own fallback instead of reusing this rule.
- [ ] In Multi-Agent Menu Bar Mode, provisionally leave Preferred Menu Bar Agent and Menu Bar Failover Policy visible but disabled, explain that they apply to Single-Agent mode, and preserve their values for restoration when the user switches back.
- [ ] Persist Preferred Menu Bar Agent independently from Settings Agent; migration defaults to Codex when Codex is connected.
- [ ] Changing Settings Agent must not change Preferred Menu Bar Agent, and changing Preferred Menu Bar Agent must not navigate or replace the current Agent Settings Page.
- [ ] Give the selector a stable Searchable Setting identity so a later move does not change its search synonyms or user-facing title.
- [ ] When additional menu-bar icon/display controls are approved, create **Menu Bar** as a Settings Destination and move the entire existing Menu Bar section there; do not duplicate the controls between General and Menu Bar.
- [ ] After that move, update the Settings Search Index destination metadata while retaining stable setting IDs so existing search behavior lands in the new location.
- [ ] Verify active, inactive/paused, connection-loss, temporary fallback, automatic return, and all-agents-disconnected states under both policies; independent Settings/Preferred Menu Bar Agent changes; relaunch persistence; Single-Agent versus future Multi-Agent control eligibility; search routing before and after the future destination move; and maximum-width labels.

### Task 8: Documentation and signed acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-settings-provider-followups.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-global-sidebar.md`
- Modify: `UsageProbe/README.md` when behavior is implemented.
- Modify: `how-to.md` when behavior is implemented.
- Modify: `outline.md` when phase status changes.
- Modify: `AGENTS.md` if the fixed-center or provider lifecycle rules become repository guardrails.

- [ ] Compile with warnings as errors and build the signed app with `CodexUsageMonitor/Scripts/build-app.sh`.
- [ ] Verify code signature, bundled plist/resources, guardrail scan, and `git diff --check`.
- [ ] Inspect all six destinations, both side-rail states, search results and scroll targets, every Boolean switch, both quota-window preference groups, and the Agents selector/context blocks.
- [ ] Exercise notification permission denial, each independent Codex window threshold, app-local disconnect/reconnect, relaunch persistence, absent quota lanes, and long provider/status strings.
- [ ] Inspect Light and Dark appearance. Record any state not directly observed rather than claiming inferred coverage.

## Requirement-to-Task Traceability

| Requested requirement | Owning task |
| --- | --- |
| Separate five-hour and weekly Window Warning Settings, eventually per agent | Task 3 |
| Disconnect button for each supported agent | Task 5 |
| Navigation Sidebar stays unchanged; Context Rail toggles visibility; Settings Page stays constant | Task 1 |
| Index and search every actionable setting across Settings Destinations | Task 2 |
| Beautify most checkboxes as toggles | Task 1 |
| Provider icon or app icon plus provider-specific notification copy | Task 4 |
| Agents header becomes supported-agent selector | Task 6 |
| Agents Context Rail shows every Paired Agent block by block | Task 6 |
| Independent Preferred Menu Bar Agent selector and future Menu Bar Settings Destination | Task 7 |

## Self-review

- Spec coverage: every requirement in the user's follow-up list maps to one task above.
- Scope control: the document does not claim Claude/GitHub support, arbitrary thresholds, provider-wide logout, custom notification icon support, or implementation completion.
- State ownership: `SettingsView` owns presentation selection; `AppSettings` owns persisted user choices; connection controllers own provider status; `QuotaMonitor` owns collection lifecycle; notification policy consumes typed provider/window state.
- Safety: Disconnect is explicitly app-local unless a later destructive provider-logout requirement is separately approved.
- Visual acceptance: fixed Navigation Sidebar and Settings Page geometry is an exact invariant, and the plan retains the repository's signed-app Light/Dark and conditional-state audit requirements.
