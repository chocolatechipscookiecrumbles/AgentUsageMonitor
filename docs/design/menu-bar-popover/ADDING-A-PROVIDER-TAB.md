# Adding a provider tab to the menu-bar popover

A template for wiring a new agent (a third provider beyond Codex and Claude)
into the `.window` popover, derived from the shipped Codex and Claude tabs. Use
the existing tabs as the reference implementation; this doc is the checklist and
the rules that keep them consistent.

Replace `<Provider>` with the new provider's name (e.g. `Copilot`) and
`<provider>` with the `AgentProvider` case.

## Prerequisite

The provider must have passed its capability gate and be a **`.supported`**
entry in `AgentSettingsCatalog`. `MenuPopoverProviderCatalog.availableProviders`
derives the tabs from the supported entries, so an unsupported provider must not
get a tab (this is why Copilot has none). Do not ship a tab backed by mock or
zeroed data — that is the "static preview" problem the capability gates exist to
prevent.

## Files to create

Model each on its Codex/Claude counterpart. Not every provider needs every file
— create only what its data and connection model require.

| File | Purpose | Reference |
|---|---|---|
| `<Provider>MenuContent.swift` | Top-level tab body: available vs. unavailable branch. | `CodexMenuContent`, `ClaudeMenuContent` |
| `<Provider>MenuPresentation.swift` | Pure mapping from the provider's model to display-ready window/credit values, **only if** the provider's own model isn't already display-ready. | Codex needs one; Claude reuses `ClaudeUsageDisplayModel` |
| `<Provider>UsageWindowCard.swift` / `Row.swift` | The stacked window cards (used% right, remaining% + reset footer). | `CodexUsageWindowCard`/`Row`, `ClaudeUsageWindowCard`/`Row` |
| `<Provider>StalenessStrip` / cached strip | Shown above the cards when the read is not live. | `CodexCachedWarningStrip`, `ClaudeStalenessStrip` |
| `<Provider>UnavailableContent.swift` | Explicit unavailable/setup card carrying the provider's connect affordance. | `CodexUnavailableContent`, `ClaudeUnavailableContent` |
| `<Provider>SignInActions` / credential actions | The provider's connect affordance(s). | `CodexSignInActions` (browser+CLI), `ClaudeCredentialActions` (credentials only) |
| `<Provider>ConnectionRecoveryCard.swift` | Recovery affordance shown *alongside* cached data when the connection is broken. | `CodexConnectionRecoveryCard`, `ClaudeConnectionRecoveryCard` |

Reuse — do **not** re-create — these shared primitives: `MenuPopoverTheme`,
`UsageProgressBar`, `MenuResetTimingPresentation`, `ProviderIconTile`,
`StatusPill`, and `NotificationPermissionStrip`.

## Wiring

1. **`MenuProviderHeaderPresentation`** — add `static func <provider>(...)`:
   - `title` = the provider name (`AgentProvider.<provider>.tabTitle`), not the app name.
   - `subtitle` = the shared freshness line via `updatedText(for:)` →
     `Updated: <time> · <relative>`. Do not invent a per-provider format.
   - `status` = `.confirmed` / `.cached` / `.refreshing` / `.unavailable` from the
     provider's own confirmed-vs-cached state.
2. **`MenuBarPopoverView`** — add the case to each switch: `providerContent`,
   `headerPresentation`, `isRefreshing`, and `refresh()`.
3. **Catalog** — make the provider `.supported` in `AgentSettingsCatalog`; the
   tab strip and `resolvedSelection` pick it up automatically.
4. **Persistence** — nothing to add. `AppSettings.selectedMenuProvider` stores
   any `AgentProvider`; `MenuPopoverProviderCatalog.resolvedSelection` keeps a
   supported selection and falls back to Codex only when unsupported.
5. **View model** — add the provider's read cycle to `QuotaViewModel` the way
   Codex's `QuotaMonitor` and Claude's `ClaudeUsageMonitor` are owned, plus a
   provider-specific `refresh<Provider>()` and `isRefreshing<Provider>`.

## Rules (non-negotiable — these keep the tabs one system)

- **Opening is passive.** No refresh, polling, timer, `TimelineView`, or
  per-second invalidation may be triggered by opening the popover or rendering a
  tab. Freshness strings are computed once at render.
- **Never invent data.** A missing window or value renders as an explicit
  unavailable line, never `0%`. A window that has reset is not shown as a live
  figure.
- **Header is uniform.** Title = provider name; freshness line = the shared
  `Updated: <time> · <relative>`. No per-provider header format.
- **Provenance goes in the content, only when it matters.** If the provider has
  multiple sources of differing authority (like Claude: OAuth / capture / cache),
  show `Read from: <source>` as a caption beneath the window card. A
  single-source provider (like Codex) omits it.
- **No cross-provider furniture.** Codex's credits/collector card stays off other
  tabs; a provider shows only what its own data contract supports.
- **Notifications are app-wide.** Use the shared `NotificationPermissionStrip`,
  shown on every tab when `notificationAuthorizationState == .denied`. Do not add
  a per-provider alerts toggle to the popover — that lives in Settings.
- **Footer.** Commands dismiss first (except Refresh Now once the deferred
  "keep open on refresh" change lands — see SPEC §7); Refresh targets the active
  provider. A provider whose credential read can prompt may do so only from an
  explicit, user-initiated action.
- **Theme only.** Use `MenuPopoverTheme` tokens and
  `AgentProvider.settingsPresentationTint`; no hardcoded provider color literals
  in views.
- **Icon.** Fill the tile only if the mark carries its own square background
  (like Codex); a transparent glyph keeps the inset (see `ProviderIconTile`).
- **Tests.** Follow the branch policy: no feature-presence tests; a provider that
  needs a presentation mapper may unit-test that pure logic (as
  `ClaudeUsageDisplayModelTests` does).

## Reference

- Layout/design contract: [SPEC.md](SPEC.md) (§3 structure, §7 refinements).
- Shipped implementation: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/`.
