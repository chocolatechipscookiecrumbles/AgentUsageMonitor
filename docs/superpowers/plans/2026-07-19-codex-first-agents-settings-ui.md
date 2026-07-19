# Codex and Claude Preview Agents Settings UI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the supplied v6 Agents visual structure into the signed macOS Settings window with a working Codex page and a clearly unavailable, selectable Claude Code preview page.

**Architecture:** `SettingsView` remains the sole owner of the global destination, Context Rail visibility, and one session-only selected Settings Agent. An explicit display catalog contains one supported entry (`.codex`) and one user-approved preview entry (`.claudeCode`); it never derives UI from `AgentProvider.allCases`. The selector changes only the displayed page and Context Rail card. Codex reads existing `QuotaViewModel` state; Claude renders static availability content and creates no adapter, scheduler, credential storage, or network request.

**Tech Stack:** Swift 6.2, SwiftUI, existing Settings layout and appearance palette, `QuotaViewModel`, `AgentConnectionState`, the signed SwiftPM application bundle.

## Global Constraints

- This plan is a UI integration only. GitHub Copilot, Claude Code connection/authentication, provider OAuth, local provider data, connection controllers, collectors, refresh scheduling, notifications, and persistence are out of scope.
- Keep Copilot capability work deferred. The experimental `copilot_internal/user` research is documented on `research/copilot-capability`; it does not authorize a GitHub Copilot row, selector item, connection state, or Settings action here.
- `AgentProvider.allCases` includes planned providers and must never drive visible Agents UI. The display catalog is explicit: `.codex` is supported and `.claudeCode` is a user-approved preview; GitHub Copilot remains absent.
- This plan is the narrow, user-approved exception to the normal supported-provider gate: Claude Code may be a selectable **Preview** page solely to port and inspect the Agents layout. It must say `Not available yet`, expose no sign-in/control, and show no connection, account, quota, or usage state. A provider becomes supported only after a real adapter exists.
- Keep the selected Settings Agent in `SettingsView` `@State` for the current open Settings window only. Do not persist it and do not connect it to any future Preferred Menu Bar Agent setting.
- Use `SettingsPage`, `SettingsSection`, `SettingsSectionRow`, `SettingsLabeledRow`, `SettingsDescription`, and `SettingsLayoutMetrics`. Do not add a `Form`, `LabeledContent`, page-local alignment values, transparent spacing views, or a second global navigation owner.
- Keep the Agent header at the existing `pageHeaderHeight` and use shared metrics for all selector insets, icon sizes, underline thickness, and inter-item spacing. It must not alter any non-Agents page header, window width, sidebar frame, Settings Page frame, or Context Rail allocation.
- The user-approved source icons live at `assets/icons for agents/` in this branch. Copy only `codex-color.svg` and `claudecode-color.svg` into a versioned app resource format with provenance recorded; retain `githubcopilot.svg` for the future Copilot plan and do not render it in this implementation. Do not use web classes, fixed web colors, or any copied VS Code/GitHub visual identity.
- Render Codex and Claude Code as native, usable selector buttons. Clicking, tabbing, pressing Space/Return, or using left/right arrows changes only the session selection and its center/Context Rail presentation. Show no overflow affordance because two entries fit at the default width. GitHub Copilot does not appear.
- Preserve all existing connection guidance and Browser/CLI sign-in actions exactly. Do not change connection-state wording, sign-in transitions, external-login reconciliation, or refresh-on-authentication behavior.
- Do not add broad test cases for this visual work. Add a narrow deterministic regression test only if a reproducible state-to-view routing defect is introduced; otherwise record signed-app visual acceptance and any unobserved states.
- Follow the Settings UI guardrails in `AGENTS.md`, including signed-app inspection at the 680 × 560-point content size, Light/Dark review, both Context Rail states, scrollability, focus, and no destination-transition workaround.

## Design decisions recorded

1. The Agents page header replaces the normal text-only title with selectable OpenAI Codex and Claude Code identity buttons. Codex is supported; Claude is marked Preview in its page and Context Rail, not in the compact selector label.
2. The center page shows the selected catalog entry. The existing generic planned-provider cards are removed. Claude’s replacement is a deliberately static preview page that states what it does not do.
3. The Context Rail follows the selected entry. Codex uses existing connection, plan, and quota-status data; Claude uses only `Preview` / `Not available yet` labels and contains no inferred provider data.
4. Use the approved Codex and Claude icon sources from `assets/icons for agents/` after converting and bundling them as native app resources. GitHub Copilot’s supplied icon remains unrendered until that provider passes its capability gate.
5. This plan deliberately stops before the broader [supported-agent selector](2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector). That task begins only when a second real adapter can truthfully populate the supported catalog; it must replace the preview exception rather than treating it as support evidence.

## Follow-on scope — 2026-07-19

The first port exposed three implementation boundaries that this follow-on completes without expanding provider capability:

1. **Apple vector asset catalog.** The original SVG files remain design-source material under `assets/icons for agents/`. The application uses their user-supplied, single-page PDF conversions in `Resources/Assets.xcassets`, with Preserve Vector Data set for each image set. The signed-app build compiles that catalog into `Assets.car`; SwiftUI loads named assets from the application bundle rather than opening raw icon files. Codex, Claude, and the retained future Copilot asset each render inside the same shared `20 × 20` slot with `16 × 16` maximum artwork, so a provider's intrinsic art bounds never alter selector geometry.
2. **Reusable provider navigation and page shell.** The visible labels become the one-word `Codex`, `Claude`, and future `Copilot`, while full provider names remain available for factual page and accessibility labels. A shared adaptive tab strip owns selection, keyboard navigation, fixed icon geometry, and an overflow strategy; every provider page uses the same `AgentSettingsPageTemplate` shell. The current two providers must use a stable non-scrolling layout, so a scroll view cannot compete with button selection. A future catalog with more entries may opt into the strip's horizontal overflow behavior without each page inventing its own navigation.
3. **Codex visual facts only.** The Codex page ports the Figma-style connection state and a current-quota/session card using existing in-memory `QuotaViewModel.presentation`: five-hour window, weekly window, and the count of banked reset credits when available. It must not show app-server path, protocol, Codex version, account identity, or credentials. Connection buttons are presented for design parity, but no new connection/disconnection behavior is introduced.

### Provider-page presentation contract — 2026-07-19

Every provider page that later has a sanitized quota presentation must use `AgentSettingsPageTemplate`, `AgentQuotaSessionSection`, `AgentQuotaWindowRow`, `AgentSettingsIcon`, and the provider's `settingsPresentationTint`; it must not duplicate per-page icon sizing, quota-bar color, or alignment offsets.

- Connection and quota facts use `SettingsPreferenceControlRow`, which keeps Status, Plan, Credits, reset counts, and expiry timestamps in the same right-aligned value column as Settings toggles and other trailing controls. Plan belongs in **Connection**, not Current quota.
- Current quota always reserves **5-Hour Window** and **Weekly Window**. A missing window renders an explicit unavailable/idle state instead of removing the row; the provider tint is applied only to a real `ProgressView` value.
- Credits and Banked resets use the existing sanitized `creditBalance` and `availableResetCredits` presentation fields. Every supplied reset-credit expiry is rendered with abbreviated month/day/year and hour/minute, matching the menu popover's date-and-time boundary. No token, account identity, or raw provider response is displayed.
- `Quota status` is intentionally absent from Current quota; connection state remains in Connection, while per-window availability is visible in the quota rows.
- `AgentProvider.settingsPresentationTint` is the one provider-color source for the selected-tab underline, provider quota bars, and Context Rail status treatment. Codex uses **#576DFF**. Future providers must add their color once there and use the shared components rather than hard-coding colors.
- The Context Rail uses the same catalog icon as the provider selector in its own shared smaller slot. It must not fall back to a provider-specific SF Symbol where a catalog asset exists.

### Alignment and quota-display correction — 2026-07-19

At the hidden-rail default width, the Settings Page is one point below the generic compact-layout breakpoint. `SettingsLabeledRow` therefore correctly changed its own layout to vertical, but that is wrong for concise provider facts: Status, Plan, Credits, Banked resets, and reset-expiry timestamps should remain aligned with the right-hand control column. Provider factual rows now use the existing `SettingsPreferenceControlRow` instead of changing the global breakpoint or introducing a local alignment constant. This keeps every other destination's compact behavior intact.

Provider quota windows receive the existing `QuotaValueMode` from General Settings. **Remaining** and **Used** control the displayed percentage and bar length for both five-hour and weekly rows; reset time remains supplemental rather than showing a conflicting second percentage.

Native `ProgressView.tint` can apply an appearance-dependent control treatment that visibly darkens the requested provider color. `ProviderQuotaProgressBar` is the required provider-page bar template: a palette-derived track plus a fully opaque foreground `Capsule` filled directly with `settingsPresentationTint`. Do not apply an additional opacity, blend mode, overlay, or native progress style to the foreground. This preserves the exact #576DFF Codex color while allowing the track to adapt to Light/Dark.

### Deferred disconnect semantics

The page may visibly reserve a disabled `Disconnect` control with plain-language availability copy. It must not act like an enabled button while doing nothing.

- **App-local disconnect** would stop this app's monitoring or mark its Codex presentation disconnected while deliberately retaining the user's independent CLI session. It is less destructive, but potentially misleading because it does not sign the user out of Codex.
- **CLI-session logout** would invoke the official `codex logout` flow, then reconcile application state. This matches a literal "Disconnect" expectation, but can unexpectedly affect other Terminal/editor Codex workflows and therefore requires an explicit product decision, confirmation design, recovery behavior, and a separate implementation/acceptance plan.

The user currently leans toward the CLI-session interpretation but has deferred both behaviors. This UI-only work must neither choose nor implement either option.

### Current execution checklist

- [x] Replace raw generated images with user-supplied, Preserve-Vector-Data PDF image sets for Codex, Claude, and retained future Copilot art.
- [x] Replace the raw-file loader with a named `Bundle.main` asset image, compile the catalog during the signed-app build, and make the signed-artifact check fail before / pass after that packaging boundary.
- [x] Standardize the tab label (`Codex`, `Claude`, future `Copilot`), fixed icon slot, adaptive tab-strip implementation, and provider-page template.
- [x] Port existing Codex connection guidance plus visible, disabled disconnect affordance; add existing five-hour/weekly quota windows and banked reset count without reading new data.
- [x] Move Plan into Connection, reserve both quota-window rows even when inactive, add the existing credits/reset-expiry fields, and centralize the #576DFF Codex color across selected-tab, quota, and Context Rail presentation.
- [x] Keep concise provider facts right-aligned below the global compact breakpoint, honor General's Remaining/Used preference in both provider quota windows, and use the opaque shared provider-bar template rather than a native tinted progress style.
- [x] Verify `swift test` (8 tests, 0 failures), build the signed app, confirm `Assets.car` contains the three named provider assets, and perform strict codesign verification. `git diff --check` also passed.
- [ ] Build and manually inspect the signed app: correct PDF artwork, repeated Codex/Claude selection, keyboard selection, disabled disconnect copy, current quota/session states, both Context Rail states, and Light/Dark. This is required before any visual-fix claim.

The historical Task 2 raster-conversion commands below record why the original source failed and are superseded by this vector-asset workflow. They are not instructions to recreate raster runtime assets.

## Signed-app icon packaging correction — 2026-07-19

Entering Agents in the signed app crashed with `EXC_BREAKPOINT` before the page could render. The macOS crash report identifies `AgentSettingsIcon.body`, then SwiftPM's generated `NSBundle.module` accessor, which calls `fatalError` because the signed app did not contain the generated resource bundle. `build-app.sh` copied the executable and `Info.plist` only, while Task 2 had introduced a SwiftPM resource target and `.module` lookup.

The initial raw-PNG correction removed the crash but the user observed that the converted Codex art was nearly blank. The durable replacement uses the user-provided PDF vectors in an Apple asset catalog. `build-app.sh` invokes `actool` to compile `Resources/Assets.xcassets` into `Contents/Resources/Assets.car`; `AgentSettingsIcon` loads a named image through `Image(_:bundle: .main)`. `Package.swift` remains an ordinary executable target, so the failing SwiftPM module-resource accessor is no longer linked into the app.

Every current and future provider icon uses the same `20 × 20`-point slot and a `16 × 16`-point maximum artwork frame from `SettingsLayoutMetrics`. Artwork therefore scales within a common window rather than moving labels or selector geometry according to its intrinsic dimensions.

`Scripts/verify-signed-app-resources.sh` is the narrow regression check. It failed before the catalog build because `Assets.car` was absent, then passed after a signed build and confirms that Codex, Claude, and retained Copilot asset names exist in the compiled catalog. Strict codesign verification also passed. A manual signed-app Agents navigation check remains required; no claim is made until it directly observes the original route without a crash and the correct vector art.

## File structure

| File | Responsibility |
| --- | --- |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsCatalog.swift` | Declare supported versus preview display entries independently of planned enum cases. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift` | Supply display title and semantic presentation tint for catalog entries. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift` | Render the compact selectable Codex/Claude header row and preserve the Context Rail control. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsTabStrip.swift` | Keep provider selection, keyboard routing, icon slots, and adaptive overflow in one reusable selector. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsPageTemplate.swift` | Give current and future provider pages the same Settings page shell without changing global navigation ownership. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift` | Own ephemeral Settings Agent selection and route the Agents header/Context Rail state. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift` | Retain the normal title header for five destinations and delegate the Agents header only for `.agents`. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift` | Pass the current Settings Agent only into the Agents destination. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift` | Render the selected supported Codex page or static Claude preview page. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift` | Keep existing Codex facts/actions but organize them as concise Connection, Usage, and Privacy cards. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeCodePreviewSettingsView.swift` | Render the static unavailable Claude Code preview page without an integration action. |
| Delete `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift` | Remove the static planned-provider Settings presentation. |
| Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift` | Render a factual Codex card or static Claude preview card for the Context Rail. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift` | Route Agents Context Rail content through `AgentConnectionsContextView`; leave five other destinations unchanged. |
| Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift` | Hold selector geometry metrics beside existing shared Settings metrics. |
| Create `CodexUsageMonitor/Resources/Assets.xcassets` | Hold user-supplied Codex, Claude, and retained Copilot PDF vector assets. |
| Modify `CodexUsageMonitor/Scripts/build-app.sh` | Compile the app asset catalog into the signed application bundle. |
| Modify `CodexUsageMonitor/Scripts/verify-signed-app-resources.sh` | Assert the compiled catalog and provider asset names are present in the signed bundle. |
| Modify `docs/product/planning-board.md` | Record the Codex-first UI integration separately from the still-deferred multi-provider selector. |
| Modify this plan | Record executed scope, signed-build results, visual evidence, and any limitation. |

---

### Task 1: Establish the supported-versus-preview display catalog

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsCatalog.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`

**Interfaces:**

```swift
enum AgentSettingsAvailability: Equatable {
    case supported
    case preview
}

struct AgentSettingsCatalogEntry: Identifiable, Equatable {
    let provider: AgentProvider
    let availability: AgentSettingsAvailability
    var id: AgentProvider { provider }
}

enum AgentSettingsCatalog {
    static let entries: [AgentSettingsCatalogEntry] = [
        .init(provider: .codex, availability: .supported),
        .init(provider: .claudeCode, availability: .preview),
    ]
}
```

- [ ] **Step 1: Add an explicit UI display catalog that does not derive from `allCases`.**

```swift
enum AgentSettingsAvailability: Equatable {
    case supported
    case preview
}

struct AgentSettingsCatalogEntry: Identifiable, Equatable {
    let provider: AgentProvider
    let availability: AgentSettingsAvailability
    var id: AgentProvider { provider }
}

enum AgentSettingsCatalog {
    static let entries: [AgentSettingsCatalogEntry] = [
        .init(provider: .codex, availability: .supported),
        .init(provider: .claudeCode, availability: .preview),
    ]
}
```

Keep the existing enum values for future planning references, but make every new Agents UI call `AgentSettingsCatalog.entries`. Add no adapter capability, availability probe, persistence, or GitHub Copilot entry.

Add a presentation-only tint to `AgentProvider`:

```swift
var settingsPresentationTint: Color {
    switch self {
    case .codex: .blue
    case .claudeCode: .orange
    case .githubCopilot: .secondary
    }
}
```

The `githubCopilot` case exists only for enum exhaustiveness and must not enter the display catalog.

- [ ] **Step 2: Let `SettingsView` own a session-only selected Settings Agent.**

Add this property beside `isPreviewVisible`:

```swift
@State private var selectedSettingsAgent: AgentProvider = .codex
```

Before passing it to child views, repair an obsolete selection without animation:

```swift
private func repairSelectedSettingsAgentIfNeeded() {
    guard !AgentSettingsCatalog.entries.contains(where: { $0.provider == selectedSettingsAgent }) else { return }
    selectedSettingsAgent = .codex
}
```

Invoke it from an `.onAppear` on `SettingsView`. Do not use `.id`, view removal/insertion, delayed state writes, or a destination-change animation; the known destination compositor defect remains deferred.

- [ ] **Step 3: Thread the selected agent solely through the Agents destination.**

Change the `.agents` branch of `SettingsDetailView` to pass the selection, and add `let selectedAgent: AgentProvider` to `AgentsSettingsView` so this routing boundary compiles. Remove its two old `PlannedAgentSettingsView` calls in the same change: retaining them would keep a visible GitHub Copilot placeholder after the display catalog explicitly excludes Copilot. Preserve the remaining Codex-only body in this task; Task 3 will make the already-threaded value select the center content and delete the now-unused generic view file.

```swift
struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider

    // Existing body remains Codex-only until Task 3.
}
```

Use the new argument from `SettingsDetailView`:

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

Expected: build succeeds. Do not add a new test for this presentation-only catalog unless this routing change creates a deterministic regression.

- [ ] **Step 5: Commit the supported-agent boundary.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsCatalog.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift
git diff --cached --check
git commit -m "Add Agents Settings display catalog"
```

Expected: no user preference, token, provider connection, or polling behavior is changed.

### Task 2: Port the compact selectable Agents header

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsIcon.swift`
- Create: `CodexUsageMonitor/Resources/AgentIcons/codex-agent.png`
- Create: `CodexUsageMonitor/Resources/AgentIcons/claude-code-agent.png`
- Modify: `CodexUsageMonitor/Package.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`

**Interfaces:**

```swift
struct AgentSettingsHeader: View {
    let entries: [AgentSettingsCatalogEntry]
    @Binding var selection: AgentProvider
    @Binding var isContextRailVisible: Bool
}

struct AgentSettingsIcon: View {
    let provider: AgentProvider
    let slotSize: CGFloat
    let artworkMaxSize: CGFloat
}

extension SettingsLayoutMetrics {
    static let agentHeaderItemHorizontalPadding: CGFloat = 12
    static let agentHeaderIconSlotSize: CGFloat = 20
    static let agentHeaderIconArtworkMaxSize: CGFloat = 16
    static let agentHeaderItemSpacing: CGFloat = 6
    static let agentHeaderUnderlineHeight: CGFloat = 2
}
```

- [ ] **Step 1: Bundle the approved Codex and Claude icon sources as native resources.**

The supplied source SVGs use `1em` dimensions that ImageMagick cannot rasterize directly. Copy each source into a private temporary file, replace only its root `height="1em"` and `width="1em"` attributes with `64`, rasterize at 64 × 64 with transparency, then delete the temporary file. Do not modify the user-owned prototype source.

```zsh
icon_source_root="assets/icons for agents"
icon_temp_dir="$(mktemp -d)"
mkdir -p CodexUsageMonitor/Resources/AgentIcons

for icon_name in codex-color claudecode-color; do
  sed 's/height="1em"/height="64"/; s/width="1em"/width="64"/' \
    "$icon_source_root/$icon_name.svg" > "$icon_temp_dir/$icon_name.svg"
done

magick -background none "$icon_temp_dir/codex-color.svg" \
  -resize 64x64 CodexUsageMonitor/Resources/AgentIcons/codex-agent.png
magick -background none "$icon_temp_dir/claudecode-color.svg" \
  -resize 64x64 CodexUsageMonitor/Resources/AgentIcons/claude-code-agent.png
rm -rf "$icon_temp_dir"
file CodexUsageMonitor/Resources/AgentIcons/codex-agent.png \
  CodexUsageMonitor/Resources/AgentIcons/claude-code-agent.png
```

Expected: two PNG files with alpha-capable native raster data. If `magick` is unavailable or either conversion fails, stop the icon task and record the tool failure; do not substitute an unofficial download, a copied web asset, or a system icon without an explicit user decision.

On 2026-07-19, ImageMagick rejected the supplied Codex SVG path data after the root-dimension substitution, while macOS Quick Look rendered that same source as a 64 × 64 RGBA PNG. Therefore, use this approved native fallback only for a failed ImageMagick conversion; it preserves the exact user-supplied SVG and does not introduce substitute artwork:

```zsh
rm -f CodexUsageMonitor/Resources/AgentIcons/codex-agent.png
qlmanage -t -s 64 -o "$icon_temp_dir" "$icon_temp_dir/codex-color.svg" >/dev/null
mv "$icon_temp_dir/codex-color.svg.png" \
  CodexUsageMonitor/Resources/AgentIcons/codex-agent.png
file CodexUsageMonitor/Resources/AgentIcons/codex-agent.png
```

Expected fallback result: `PNG image data, 64 x 64, 8-bit/color RGBA`. If native Quick Look also fails, stop the icon task and record the failure; do not substitute an unofficial download, copied web asset, or system icon.

Keep `Package.swift` as the ordinary executable target; do not make the icons a SwiftPM module resource. The signed app is assembled outside SwiftPM, so `build-app.sh` must install both checked-in PNGs into `Contents/Resources` after installing `Info.plist`:

```zsh
for resource in codex-agent.png claude-code-agent.png; do
  install -m 644 "$root/Resources/AgentIcons/$resource" "$app/Contents/Resources/$resource"
done
```

`Scripts/verify-signed-app-resources.sh` must fail when either resource is absent and pass after the signed build. This prevents the `Bundle.module` crash found during implementation.

- [ ] **Step 2: Add all Agents-header geometry values to `SettingsLayoutMetrics`.**

Add the four values above; do not introduce file-local numeric padding or a new fixed Settings Page width. The existing `pageHeaderHeight` remains `52`, so the row is content-sized within the same window geometry as every other destination.

- [ ] **Step 3: Implement `AgentSettingsIcon` and the Codex/Claude selector buttons.**

Implement the icon view with the two bundled names and no GitHub fallback:

```swift
var body: some View {
    Image(provider == .codex ? "codex-agent" : "claude-code-agent", bundle: .main)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
}
```

Call `AgentSettingsIcon(provider: entry.provider, size: SettingsLayoutMetrics.agentHeaderIconSize)` only after the catalog guarantees the entry is Codex or Claude.

Use the existing palette and a standard header `HStack`. Its leading content is:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 0) {
        ForEach(entries) { entry in
            Button {
                selection = entry.provider
            } label: {
                HStack(spacing: SettingsLayoutMetrics.agentHeaderItemSpacing) {
                    AgentSettingsIcon(
                        provider: entry.provider,
                        size: SettingsLayoutMetrics.agentHeaderIconSize
                    )
                    Text(entry.provider.title)
                }
                    .font(.system(size: 14, weight: selection == entry.provider ? .semibold : .regular))
                    .foregroundStyle(selection == entry.provider ? .primary : .secondary)
                    .padding(.horizontal, SettingsLayoutMetrics.agentHeaderItemHorizontalPadding)
                    .frame(height: SettingsLayoutMetrics.pageHeaderHeight)
                    .overlay(alignment: .bottom) {
                        if selection == entry.provider {
                            Rectangle()
                                .fill(entry.provider.settingsPresentationTint)
                                .frame(height: SettingsLayoutMetrics.agentHeaderUnderlineHeight)
                                .accessibilityHidden(true)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.provider.title)
            .accessibilityValue(selection == entry.provider ? "Selected" : "Not selected")
            .accessibilityAddTraits(selection == entry.provider ? .isSelected : [])
        }
    }
}
```

Place the underline as a bottom overlay on the identity item rather than as an unconstrained `Rectangle` in a stack. Match the existing header’s 20-point outer horizontal inset, use `palette.windowBackground`, and keep the existing borderless Context Rail button at the trailing edge with the same labels/help/value.

Set the outer `ScrollView` to the existing header height and retain the existing 20-point outer header inset. Add `.onMoveCommand` at the selector row: `.left` selects the prior entry, `.right` selects the next, and both clamp at endpoints. Native buttons retain Tab, Space, and Return activation. Do not show an overflow indicator while both entries fit. Keep the catalog/selection interface so the deferred real-provider selector can replace the preview exception without moving window-level state.

- [ ] **Step 4: Use the agent header only for `.agents`.**

Give `SettingsPageHeader` a `selection: SettingsTab`, `entries: [AgentSettingsCatalogEntry]`, and `selectedAgent` binding. Preserve the existing title-header branch for every non-Agents destination:

```swift
if selection == .agents {
    AgentSettingsHeader(
        entries: entries,
        selection: selectedAgent,
        isContextRailVisible: $isPreviewVisible
    )
} else {
    standardTitleHeader
}
```

The new header must own no global destination state, must not create a second sidebar, and must not attach a destination identity or transition.

- [ ] **Step 5: Check the header geometry and bundled icons in the signed app.**

Run:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
zsh CodexUsageMonitor/Scripts/verify-signed-app-resources.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
```

Open only the temporary signed app instance through normal UI paths. At the default Settings size, inspect General → Agents → General with the Context Rail hidden and visible. Verify that General retains its ordinary title, Agents has compact Codex and Claude buttons, click and keyboard change selection, the rail button remains in the same trailing position, no page becomes wider, and no old/new text overlaps during destination switching. Quit only the temporary app instance started for the audit.

- [ ] **Step 6: Commit the header port.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsIcon.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPageHeader.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift \
  CodexUsageMonitor/Resources/AgentIcons/codex-agent.png \
  CodexUsageMonitor/Resources/AgentIcons/claude-code-agent.png \
  CodexUsageMonitor/Package.swift
git diff --cached --check
git commit -m "Port selectable Agents header"
```

### Task 3: Replace planned-provider cards with selected Codex and Claude-preview content

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeCodePreviewSettingsView.swift`
- Delete: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift`

**Interfaces:**

```swift
struct AgentsSettingsView: View {
    @ObservedObject var viewModel: QuotaViewModel
    let selectedAgent: AgentProvider
}
```

- [ ] **Step 1: Render the selected Codex page or explicit Claude preview page.**

Replace the stacked planned-provider presentation with:

```swift
SettingsPage {
    switch selectedAgent {
    case .codex:
        CodexAgentSettingsView(
            status: viewModel.settingsStatus,
            connectionState: viewModel.connectionState,
            signInWithBrowser: viewModel.signInWithBrowser,
            signInWithCLI: viewModel.signInWithCLI,
            checkConnection: viewModel.checkCodexConnection
        )
    case .claudeCode:
        ClaudeCodePreviewSettingsView()
    case .githubCopilot:
        EmptyView()
    }
}
```

`selectedAgent` can only be `.codex` or `.claudeCode` through Task 1. The GitHub Copilot branch is unreachable after owner repair and must remain empty; do not turn it into a visible placeholder.

- [ ] **Step 2: Tighten the Codex page into factual cards without changing controls.**

Retain the existing status, plan, quota state, connection guidance, Browser/CLI sign-in actions, Check again action, and privacy text. Reorganize them into the following compact sections using `SettingsSectionRow` separators:

| Section | Required content |
| --- | --- |
| **OpenAI Codex** | Status, optional Plan, and Quota status. |
| **Connection** | Existing guidance and the same conditionally enabled actions. |
| **Privacy** | Existing statement that Codex owns sign-in/credential storage and the app exposes no email, fingerprint, credential, or token. |

Do not add a Disconnect action, account name, account identifier, inferred usage, new button style, custom toggle, or a provider setting. Keep descriptions at callout size and keep the current row/padding metrics.

- [ ] **Step 3: Implement the static Claude preview and remove the obsolete generic provider view.**

Create `ClaudeCodePreviewSettingsView` with exactly these sections:

```swift
SettingsSection("Claude Code") {
    SettingsSectionRow {
        SettingsLabeledRow("Status") { Text("Not available yet") }
    }
    SettingsSectionRow(showsDivider: false) {
        SettingsDescription("This preview demonstrates the Agents Settings layout only. Claude Code is not connected, and this app does not read its files, credentials, usage, or account data.")
    }
}

SettingsSection("Availability") {
    SettingsSectionRow(showsDivider: false) {
        SettingsDescription("A Claude Code integration requires a separate capability and privacy plan before connection, refresh, or notification controls can be offered.")
    }
}
```

Delete `PlannedAgentSettingsView.swift` and all references. The product roadmap and planning board remain the only location that names planned integrations until an adapter is complete.

- [ ] **Step 4: Build and inspect connected and disconnected Codex states.**

Run:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
```

Expected: existing tests pass; signed bundle builds. In the signed app, inspect Codex while connected and while normal existing disconnected guidance is visible, then switch to Claude. Verify descriptions wrap, no control escapes the trailing gutter, the content scrolls, Browser/CLI actions remain on Codex only, Claude contains no interactive connection/usage control, and GitHub Copilot never appears.

- [ ] **Step 5: Commit the Codex-first page.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeCodePreviewSettingsView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/PlannedAgentSettingsView.swift
git diff --cached --check
git commit -m "Add Claude preview Agents page"
```

### Task 4: Port the selected Agent Status Context Rail

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`

**Interfaces:**

```swift
struct AgentConnectionsContextView: View {
    let provider: AgentProvider
    let connectionState: AgentConnectionState
    let status: SettingsStatus
}
```

- [ ] **Step 1: Implement a factual Codex card and static Claude preview card.**

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

Derive `planValue` only from existing facts:

```swift
private var planValue: String {
    guard case .connected(let account) = connectionState else { return "Unavailable" }
    return account.planType?.capitalized ?? status.planName ?? "Unavailable"
}
```

For `.claudeCode`, render a separate static card with `Status: Preview` and `Availability: Not available yet`, plus the same no-data explanation used by `ClaudeCodePreviewSettingsView`. Do not include an account name, quota percentage, last-refresh inference, connection claim, or predicted data for Claude. Do not render GitHub Copilot.

- [ ] **Step 2: Route only the Agents Context Rail through the new card.**

Extend `SettingsPreviewView` with `selectedAgent`, `connectionState`, and `settingsStatus` inputs from `SettingsView`. In the `.agents` switch branch, render `AgentConnectionsContextView` for `selectedAgent`. Preserve the existing General, Notifications, Refresh, Data & Privacy, and Diagnostics branches without content changes.

- [ ] **Step 3: Perform a complete signed visual acceptance.**

Build the signed app and inspect all six Settings destinations at the default 680 × 560-point size in Light and Dark appearance, with the Context Rail hidden then visible. For Agents specifically, verify:

- the selected Codex or Claude card is shown only when the rail is visible;
- Codex status, plan fallback, and quota status match the center content;
- Claude shows only `Preview` / `Not available yet`, with no account, connection, quota, or usage claim;
- there is no GitHub Copilot row or click target;
- sidebar/page frames and the rail toggle stay stable;
- Agents content remains scrollable and does not clip at the leading or trailing edge;
- General → Agents → Notifications has no new destination-transition overlap, displacement, or opacity workaround.

If a state cannot be safely produced, record it as not run. Do not manufacture credentials, modify an account, attach a debugger, or terminate a user-owned app.

- [ ] **Step 4: Commit the Context Rail.**

```zsh
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentConnectionsContextView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsPreviewView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift
git diff --cached --check
git commit -m "Add selected agent status context rail"
```

### Task 5: Record acceptance and retain the provider gate

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md`
- Modify: `docs/product/planning-board.md`

- [ ] **Step 1: Update this plan with exact evidence.**

Replace only completed checkboxes and record commands, test counts, signed-build/codesign output, direct visual states, and unrun manual states. Do not claim a Claude adapter, Copilot connection, Claude data access, or a broad transition repair.

- [ ] **Step 2: Add a separate planning-board row.**

Add this row without changing the broader multi-provider selector’s Deferred state:

```markdown
| Codex and Claude Preview Agents Settings UI integration | **Queued** | Port the v6 structural reference as a supported Codex page plus a selectable, static Claude preview page and matching read-only rail; keep GitHub Copilot absent until its capability gate passes. | [Agents UI plan](../superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md), [provider selector gate](../superpowers/plans/2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector) |
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

Expected: no whitespace errors; no generic `PlannedAgentSettingsView` rendering remains; existing tests pass. The explicit Claude preview and `AgentProvider` references are intentional. GitHub Copilot must not be rendered by an Agents Settings view.

- [ ] **Step 4: Commit documentation.**

```zsh
git add docs/superpowers/plans/2026-07-19-codex-first-agents-settings-ui.md \
  docs/product/planning-board.md
git diff --cached --check
git commit -m "Document Codex and Claude preview Agents UI"
```

## Acceptance criteria

- Agents shows compact, selectable OpenAI Codex and Claude Code identity buttons; click and keyboard selection update the page and Context Rail for the open Settings window only.
- Codex renders factual center/Context Rail content. Claude renders only a static Preview/Not available page and card. GitHub Copilot does not appear in the live Settings UI.
- Existing connection state, plan, quota-status, privacy, Browser sign-in, CLI sign-in, and Check again behavior are preserved without new credential or network access.
- General, Notifications, Refresh, Data & Privacy, and Diagnostics retain their title header, geometry, Context Rail behavior, and content.
- The signed app is built and directly inspected in Light and Dark with the rail hidden/visible; affected states that are not observed are recorded rather than inferred.
- A real multi-provider selector, Claude adapter, OpenCode integration, and Copilot experimental integration remain explicitly Deferred.
