# Codex-First Agents Settings UI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the supplied v6 Agents visual structure into the signed macOS Settings window as a compact, Codex-first experience without showing unsupported providers as selectable or connected.

**Architecture:** `SettingsView` remains the sole owner of the global destination, Context Rail visibility, and one session-only selected Settings Agent. A small supported-agent catalog returns only `.codex`, so the Agents header renders a selected Codex identity row today while retaining a clear insertion point for the separately deferred multi-provider selector. The Agents detail and Context Rail derive their Codex status from existing `QuotaViewModel` state; they do not create an adapter, a scheduler, credential storage, or a network request.

**Tech Stack:** Swift 6.2, SwiftUI, existing Settings layout and appearance palette, `QuotaViewModel`, `AgentConnectionState`, the signed SwiftPM application bundle.

## Global Constraints

- This plan is a UI integration only. GitHub Copilot, Claude Code, provider OAuth, local provider data, connection controllers, collectors, refresh scheduling, notifications, and persistence are out of scope.
- Keep Copilot capability work deferred. The experimental `copilot_internal/user` research is documented on `research/copilot-capability`; it does not authorize a GitHub Copilot row, selector item, connection state, or Settings action here.
- `AgentProvider.allCases` includes planned providers and must never drive visible Agents UI. The initial supported-agent collection contains only `.codex`.
- Do not display Claude Code or GitHub Copilot as disabled tabs, “coming soon” pills, planned status blocks, or empty detail cards. A provider appears only after a real adapter declares it supported.
- Keep the selected Settings Agent in `SettingsView` `@State` for the current open Settings window only. Do not persist it and do not connect it to any future Preferred Menu Bar Agent setting.
- Use `SettingsPage`, `SettingsSection`, `SettingsSectionRow`, `SettingsLabeledRow`, `SettingsDescription`, and `SettingsLayoutMetrics`. Do not add a `Form`, `LabeledContent`, page-local alignment values, transparent spacing views, or a second global navigation owner.
- Keep the Agent header at the existing `pageHeaderHeight` and use shared metrics for all selector insets, icon sizes, underline thickness, and inter-item spacing. It must not alter any non-Agents page header, window width, sidebar frame, Settings Page frame, or Context Rail allocation.
- The supplied v6 React package is a visual reference, not a production asset source. Use existing SF Symbols and semantic colors (`SettingsTab.agents.navigationTint` / system tint); do not copy its SVG brand marks, `#` color values, web classes, or VS Code/GitHub visual identity into the app.
- With one supported provider, show a static selected Codex identity treatment without an inactive chevron, disabled control, horizontal overflow affordance, or keyboard selection loop. The deferred multi-provider plan owns scrolling, overflow, left/right navigation, and provider-specific accent tokens after a second real adapter exists.
- Preserve all existing connection guidance and Browser/CLI sign-in actions exactly. Do not change connection-state wording, sign-in transitions, external-login reconciliation, or refresh-on-authentication behavior.
- Do not add broad test cases for this visual work. Add a narrow deterministic regression test only if a reproducible state-to-view routing defect is introduced; otherwise record signed-app visual acceptance and any unobserved states.
- Follow the Settings UI guardrails in `AGENTS.md`, including signed-app inspection at the 680 × 560-point content size, Light/Dark review, both Context Rail states, scrollability, focus, and no destination-transition workaround.

## Design decisions recorded

1. The Agents page header replaces the normal text-only title with a one-item Codex identity row that visually establishes the future selector location. It is not an interactive control until another supported provider exists.
2. The center page shows only the selected supported agent. The existing static Claude and GitHub Copilot roadmap cards are removed; roadmap state belongs in planning documents, not live Settings content.
3. The Context Rail shows one read-only **Agent Status** card for Codex, using existing connection, plan, and quota-status data. It never claims planned integrations or infers account identity.
4. Codex uses the existing `sparkles` SF Symbol and the Agents destination’s semantic blue tint. Approved provider brand assets and per-provider primary colors remain a future visual decision.
5. This plan deliberately stops before the broader [supported-agent selector](2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector). That task begins only when at least two adapters can truthfully populate the catalog.

## File structure

| File | Responsibility |
| --- | --- |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift` | Declare the UI-visible supported-agent collection independently of planned enum cases. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift` | Render the compact, Codex-first header identity row and preserve the Context Rail control. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift` | Own ephemeral Settings Agent selection and route the Agents header/Context Rail state. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift` | Retain the normal title header for five destinations and delegate the Agents header only for `.agents`. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift` | Pass the current Settings Agent only into the Agents destination. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift` | Render the selected supported agent only. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift` | Keep existing Codex facts/actions but organize them as concise Connection, Usage, and Privacy cards. |
| Delete `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift` | Remove the static planned-provider Settings presentation. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift` | Render the read-only Codex status card for the Context Rail. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift` | Route Agents Context Rail content through `AgentConnectionsContextView`; leave five other destinations unchanged. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift` | Hold selector geometry metrics beside existing shared Settings metrics. |
| Modify `docs/product/planning-board.md` | Record the Codex-first UI integration separately from the still-deferred multi-provider selector. |
| Modify this plan | Record executed scope, signed-build results, visual evidence, and any limitation. |

---

### Task 1: Establish the Codex-only supported-agent boundary

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`

**Interfaces:**

```swift
extension AgentProvider {
    static let supportedSettingsAgents: [Self] = [.codex]
}

// Owned by the currently open Settings window only.
@State private var selectedSettingsAgent: AgentProvider = .codex
```

- [ ] **Step 1: Add a UI-visible supported collection that does not derive from `allCases`.**

```swift
extension AgentProvider {
    static let supportedSettingsAgents: [Self] = [.codex]
}
```

Keep the existing enum values for future planning references, but make every new Agents UI call `supportedSettingsAgents`. Do not add adapter capability, availability probing, persistence, or an entry for Claude/Copilot.

- [ ] **Step 2: Let `SettingsView` own a session-only selected Settings Agent.**

Add this property beside `isPreviewVisible`:

```swift
@State private var selectedSettingsAgent: AgentProvider = .codex
```

Before passing it to child views, repair an obsolete selection without animation:

```swift
private func repairSelectedSettingsAgentIfNeeded() {
    guard !AgentProvider.supportedSettingsAgents.contains(selectedSettingsAgent) else { return }
    selectedSettingsAgent = .codex
}
```

Invoke it from an `.onAppear` on `SettingsView`. Do not use `.id`, view removal/insertion, delayed state writes, or a destination-change animation; the known destination compositor defect remains deferred.

- [ ] **Step 3: Thread the selected agent solely through the Agents destination.**

Change the `.agents` branch of `SettingsDetailView` to pass the selection:

```swift
case .agents:
    AgentsSettingsView(
        viewModel: viewModel,
        selectedAgent: selectedSettingsAgent
    )
```

Add `let selectedSettingsAgent: AgentProvider` to `SettingsDetailView`, pass it from `SettingsView`, and leave all five non-Agents branches byte-for-byte behaviorally equivalent.

- [ ] **Step 4: Compile the routing boundary before visual work.**

Run:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor
```

Expected: build succeeds. Do not add a new test for the static one-provider catalog unless this routing change creates a deterministic regression.

- [ ] **Step 5: Commit the supported-agent boundary.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift
git diff --cached --check
git commit -m "Add Codex-first Settings agent state"
```

Expected: no user preference, token, provider connection, or polling behavior is changed.

### Task 2: Port the compact Codex identity header

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`

**Interfaces:**

```swift
struct AgentSettingsHeader: View {
    let providers: [AgentProvider]
    @Binding var selection: AgentProvider
    @Binding var isContextRailVisible: Bool
}

extension SettingsLayoutMetrics {
    static let agentHeaderItemHorizontalPadding: CGFloat = 12
    static let agentHeaderIconSize: CGFloat = 16
    static let agentHeaderItemSpacing: CGFloat = 6
    static let agentHeaderUnderlineHeight: CGFloat = 2
}
```

- [ ] **Step 1: Add all Agents-header geometry values to `SettingsLayoutMetrics`.**

Add the four values above; do not introduce file-local numeric padding or a new fixed Settings Page width. The existing `pageHeaderHeight` remains `52`, so the row is content-sized within the same window geometry as every other destination.

- [ ] **Step 2: Implement `AgentSettingsHeader` with a one-item static identity row.**

Use the existing palette and a standard header `HStack`. The central leading content is:

```swift
HStack(spacing: SettingsLayoutMetrics.agentHeaderItemSpacing) {
    Image(systemName: selection.systemImage)
        .font(.system(size: SettingsLayoutMetrics.agentHeaderIconSize, weight: .medium))
        .foregroundStyle(SettingsTab.agents.navigationTint)

    Text(selection.title)
        .font(.system(size: 15, weight: .semibold))
}
.padding(.horizontal, SettingsLayoutMetrics.agentHeaderItemHorizontalPadding)
.frame(height: SettingsLayoutMetrics.pageHeaderHeight)
.overlay(alignment: .bottom) {
    Rectangle()
        .fill(SettingsTab.agents.navigationTint)
        .frame(height: SettingsLayoutMetrics.agentHeaderUnderlineHeight)
        .accessibilityHidden(true)
}
```

Place the underline as a bottom overlay on the identity item rather than as an unconstrained `Rectangle` in a stack. Match the existing header’s 20-point outer horizontal inset, use `palette.windowBackground`, and keep the existing borderless Context Rail button at the trailing edge with the same labels/help/value.

Because `providers == [.codex]`, render the identity item as non-button content with an accessibility label of `OpenAI Codex, selected agent`; do not render an overflow affordance or a nonfunctional selection action. Keep the `providers`/`selection` interface so the later supported-agent-selector plan can replace this implementation without moving window-level state.

- [ ] **Step 3: Use the agent header only for `.agents`.**

Give `SettingsPageHeader` a `selection: SettingsTab`, `providers: [AgentProvider]`, and `selectedAgent` binding. Preserve the existing title-header branch for every non-Agents destination:

```swift
if selection == .agents {
    AgentSettingsHeader(
        providers: providers,
        selection: selectedAgent,
        isContextRailVisible: $isPreviewVisible
    )
} else {
    standardTitleHeader
}
```

The new header must own no global destination state, must not create a second sidebar, and must not attach a destination identity or transition.

- [ ] **Step 4: Check the header geometry in the signed app.**

Run:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
```

Open only the temporary signed app instance through normal UI paths. At the default Settings size, inspect General → Agents → General with the Context Rail hidden and visible. Verify that General retains its ordinary title, Agents has one compact Codex identity row, the rail button remains in the same trailing position, no page becomes wider, and no old/new text overlaps during destination switching. Quit only the temporary app instance started for the audit.

- [ ] **Step 5: Commit the header port.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift
git diff --cached --check
git commit -m "Port Codex-first Agents header"
```

### Task 3: Replace planned-provider cards with selected Codex content

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Delete: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift`

**Interfaces:**

```swift
struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider
}
```

- [ ] **Step 1: Render the selected supported agent only.**

Replace the stacked planned-provider presentation with:

```swift
SettingsPage {
    if selectedAgent == .codex {
        CodexAgentSettingsView(
            status: viewModel.settingsStatus,
            connectionState: viewModel.connectionState,
            signInWithBrowser: viewModel.signInWithBrowser,
            signInWithCLI: viewModel.signInWithCLI,
            checkConnection: viewModel.checkCodexConnection
        )
    }
}
```

`selectedAgent` can only be `.codex` through Task 1. Do not substitute a Claude/Copilot fallback view or show a “not implemented” row if that invariant changes; repair the state at the `SettingsView` owner instead.

- [ ] **Step 2: Tighten the Codex page into factual cards without changing controls.**

Retain the existing status, plan, quota state, connection guidance, Browser/CLI sign-in actions, Check again action, and privacy text. Reorganize them into the following compact sections using `SettingsSectionRow` separators:

| Section | Required content |
| --- | --- |
| **OpenAI Codex** | Status, optional Plan, and Quota status. |
| **Connection** | Existing guidance and the same conditionally enabled actions. |
| **Privacy** | Existing statement that Codex owns sign-in/credential storage and the app exposes no email, fingerprint, credential, or token. |

Do not add a Disconnect action, account name, account identifier, inferred usage, new button style, custom toggle, or a provider setting. Keep descriptions at callout size and keep the current row/padding metrics.

- [ ] **Step 3: Remove the obsolete static planned-provider view.**

Delete `PlannedAgentSettingsView.swift` and all references. The product roadmap and planning board remain the only location that names planned integrations until an adapter is complete.

- [ ] **Step 4: Build and inspect connected and disconnected Codex states.**

Run:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
```

Expected: existing tests pass; signed bundle builds. In the signed app, inspect Agents while Codex is connected and while normal existing disconnected guidance is visible. Verify descriptions wrap, no control escapes the trailing gutter, the content scrolls, Browser/CLI actions retain their existing behavior, and no Claude/Copilot content appears.

- [ ] **Step 5: Commit the Codex-first page.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift
git diff --cached --check
git commit -m "Show only supported agent Settings content"
```

### Task 4: Port the read-only Codex Agent Status Context Rail

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift`

**Interfaces:**

```swift
struct AgentConnectionsContextView: View {
    let provider: AgentProvider
    let connectionState: AgentConnectionState
    let status: SettingsStatus
}
```

- [ ] **Step 1: Implement one factual Agent Status card.**

Compose the existing `SettingsContextCard`, `SettingsContextValue`, and `SettingsContextValueRow`; do not make it a button. For Codex, render:

```swift
SettingsContextCard("Agent Status") {
    Label(connectionState.displayName, systemImage: provider.systemImage)
        .foregroundStyle(SettingsTab.agents.navigationTint)

    SettingsPaletteDivider()
    SettingsContextValueRow(SettingsContextValue(label: "Current", value: provider.title))
    SettingsContextValueRow(SettingsContextValue(label: "Plan", value: planValue))
    SettingsContextValueRow(SettingsContextValue(label: "Quota status", value: status.displayMode.displayName))
}
```

Derive `planValue` from the already exposed connected-plan information when available; otherwise show `Unavailable`. Do not include an account name, count “2 integrations,” quota percentage, last-refresh inference, or a predicted Copilot/Claude state.

- [ ] **Step 2: Route only the Agents Context Rail through the new card.**

Extend `SettingsPreviewView` with `selectedAgent`, `connectionState`, and `settingsStatus` inputs from `SettingsView`. In the `.agents` switch branch, render `AgentConnectionsContextView` for `selectedAgent`. Preserve the existing General, Notifications, Refresh, Data & Privacy, and Diagnostics branches without content changes.

- [ ] **Step 3: Perform a complete signed visual acceptance.**

Build the signed app and inspect all six Settings destinations at the default 680 × 560-point size in Light and Dark appearance, with the Context Rail hidden then visible. For Agents specifically, verify:

- one Codex Status card is shown only when the rail is visible;
- its status, plan fallback, and quota status match the center content;
- there is no Planned count, provider-brand asset, or click target;
- sidebar/page frames and the rail toggle stay stable;
- Agents content remains scrollable and does not clip at the leading or trailing edge;
- General → Agents → Notifications has no new destination-transition overlap, displacement, or opacity workaround.

If a state cannot be safely produced, record it as not run. Do not manufacture credentials, modify an account, attach a debugger, or terminate a user-owned app.

- [ ] **Step 4: Commit the Context Rail.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift
git diff --cached --check
git commit -m "Add Codex agent status context rail"
```

### Task 5: Record acceptance and retain the provider gate

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md`
- Modify: `docs/product/planning-board.md`

- [ ] **Step 1: Update this plan with exact evidence.**

Replace only completed checkboxes and record commands, test counts, signed-build/codesign output, direct visual states, and unrun manual states. Do not claim a provider adapter, real selector switching, a Copilot connection, or a broad transition repair.

- [ ] **Step 2: Add a separate planning-board row.**

Add this row without changing the broader multi-provider selector’s Deferred state:

```markdown
| Codex-first Agents Settings UI integration | **Queued** | Port the v6 structural reference as a single supported Codex identity header, factual Codex detail, and read-only status rail; keep planned providers absent until adapters exist. | [Codex-first Agents UI plan](../superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md), [provider selector gate](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector) |
```

After implementation, update it to **Verification** only when the signed-app acceptance in Task 4 is directly observed; otherwise retain **Queued** and list the missing check.

- [ ] **Step 3: Run final documentation and source checks.**

```zsh
git diff --check
rg -n "PlannedAgentSettingsView|Planned.*integrations|githubCopilot|claudeCode" \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings \
  docs/product/planning-board.md
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
```

Expected: no whitespace errors; no planned-provider rendering remains in the Settings source; existing tests pass. Mentions in `AgentProvider` and planning documents are allowed because they do not render a provider.

- [ ] **Step 4: Commit documentation.**

```zsh
git add docs/superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md \
  docs/product/planning-board.md
git diff --cached --check
git commit -m "Plan Codex-first Agents Settings UI"
```

## Acceptance criteria

- Agents shows one compact OpenAI Codex identity row and no interactive/simulated provider switcher.
- Only Codex renders center-page and Context Rail content; Claude Code and GitHub Copilot do not appear in the live Settings UI.
- Existing connection state, plan, quota-status, privacy, Browser sign-in, CLI sign-in, and Check again behavior are preserved without new credential or network access.
- General, Notifications, Refresh, Data & Privacy, and Diagnostics retain their title header, geometry, Context Rail behavior, and content.
- The signed app is built and directly inspected in Light and Dark with the rail hidden/visible; affected states that are not observed are recorded rather than inferred.
- The broader multi-provider selector and Copilot experimental integration remain explicitly Deferred.
