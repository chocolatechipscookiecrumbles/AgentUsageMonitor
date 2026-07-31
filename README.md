# AgentUsageMonitor

**Your Codex and Claude Code usage limits, in the macOS menu bar.**

A lightweight, privacy-first menu-bar app that shows how much of your AI coding
usage is left — the five-hour and weekly limits for **OpenAI Codex** and **Claude
Code** — with reset countdowns, a per-provider popover, a local token monitor, and
optional quota alerts. It reads sessions you already have on your machine. It never
asks for a password, and no prompt, response, or file content ever leaves your Mac.

`macOS 14+` · `Swift 6` · `menu-bar only (no Dock icon)` · `MIT licensed` ·
`version 0.0.1`

> **Naming:** the project and local clone name are now **AgentUsageMonitor**. The
> published 0.0.1 app still displays **Agent Monitor**, while its bundle, download,
> target, and source directory remain `CodexUsageMonitor` for compatibility. The
> public repository is **AgentUsageMonitor**. Compatibility names such as the
> Swift target and Application Support directory remain `CodexUsageMonitor`.

---

> ### ⚠️ Read this before installing
>
> Claude support works by reusing the OAuth credential **Claude Code already stored
> in your Keychain**. **Anthropic's Terms of Service do not permit a third-party
> application to do that.** This build does it anyway, and says so here rather than
> burying it — see [How Claude usage is read](#how-claude-usage-is-read-and-the-terms-caveat).
> Using it may put your Anthropic account at risk of enforcement; that risk is yours
> to weigh. Codex support carries no such caveat, and Claude can be turned off
> entirely in **Settings → Agents**.

---

## Contents

- [Install](#install)
- [Requirements](#requirements)
- [What it monitors](#what-it-monitors)
- [Features](#features)
- [Settings reference](#settings-reference)
- [Privacy and data](#privacy-and-data)
- [How Claude usage is read, and the terms caveat](#how-claude-usage-is-read-and-the-terms-caveat)
- [Roadmap](#roadmap)
- [Known limitations](#known-limitations)
- [FAQ](#faq)
- [Architecture](#architecture)
- [Development](#development)
- [Documentation](#documentation)
- [License](#license)

## Install

### Download

1. Grab `AgentUsageMonitor-0.0.1.zip` from the
   [latest release](https://github.com/chocolatechipscookiecrumbles/AgentUsageMonitor/releases/latest).
2. Unzip it and move **AgentUsageMonitor.app** to `/Applications`.
3. Launch it. **It lives in the menu bar** — there is no Dock icon and no window on
   first launch. Look at the right end of the menu bar.

The planned first-launch connection policy will start both providers app-locally
disconnected and require separate, explicit Connect actions for Codex and Claude,
even when their CLIs already have sessions. Version 0.0.1 does not yet enforce that
consent boundary consistently.

The published 0.0.1 download is signed with an Apple **Developer ID** certificate,
notarized, and stapled. On 2026-07-31 the uploaded archive was downloaded again,
accepted by Gatekeeper, launched, and observed working as intended.

### Build from source

```sh
git clone https://github.com/chocolatechipscookiecrumbles/AgentUsageMonitor.git
cd "AgentUsageMonitor/CodexUsageMonitor"

swift build          # compile
swift test           # run the test suite

./Scripts/build-app.sh                    # bundle + sign the .app
./Scripts/verify-signed-app-resources.sh  # confirm the catalog and bridge are inside
```

`build-app.sh` produces `.build/CodexUsageMonitor.app`. It builds `-c release`,
compiles the asset catalog, builds the bundle `.icns`, and signs the nested Claude
bridge before signing the app. Without a Developer ID certificate it falls back to
ad-hoc signing and warns you — fine for local use, but see
[Known limitations](#known-limitations) for the Keychain-prompt consequence.

> **Note:** design and binary assets are not tracked in this repository, so a fresh
> clone can `swift build` but cannot run `build-app.sh` until
> `CodexUsageMonitor/Resources/Assets.xcassets` is supplied separately.

## Requirements

| | |
|---|---|
| **OS** | macOS 14 (Sonoma) or later |
| **Codex support** | The Codex CLI, already signed in |
| **Claude support** | Claude Code, already signed in |
| **Runtime** | None. The Claude usage bridge is currently a second native Swift executable bundled and signed inside the app — no Python needed |
| **Accounts** | None. The app adds no account, network login, or credential of its own |

You need at least one of the two providers; neither is required for the other to
work.

## What it monitors

| Provider | Source | What is read | Refresh floor | Leaves your machine |
|---|---|---|---|---|
| **OpenAI Codex** | Local Codex CLI app-server | Five-hour and weekly quota, reset times, plan | Full range (as fast as 30s in Automatic) | No |
| **Claude Code** | Keychain OAuth credential → statusLine snapshot → local cache | Five-hour and weekly quota, reset times, plan, extra-usage amount | Never faster than 5 minutes | No |
| **Token Monitor** (both) | Codex and Claude Code's own local record files | Token counts, models, timestamps | Filesystem events, incremental | No |
| GitHub Copilot | — | **Not supported** — no personal-quota API has been verified | — | — |
| OpenCode | — | **Not supported** — reports connected providers, not a personal quota | — | — |

Both supported providers reuse a session you already established with the
provider's own tool. The reads are strictly one-way: the app never writes to a
provider's credential store, never signs you out, and never sends a prompt.

## Features

### Menu bar

- **Three display styles**, chosen in **General**:
  - **5-hour and weekly** — a compact two-line text readout.
  - **Bars** — 34-point graphical quota bars, stacked per provider.
  - **Combined** — one bar set combining both providers' windows.
- When exactly one provider is connected, the graphical styles collapse to a
  **two-bar single-provider layout** instead of leaving an empty lane.
- **Remaining or Used** — show the percentage left or the percentage consumed.
- **Provider glyph** in the menu bar, rendered as a template so it tints correctly
  in both Light and Dark menu bars.
- Cached versus confirmed readings are distinguished, so a stale number never
  masquerades as a live one.

### Popover

Click the menu-bar item for a per-provider panel:

- **Provider tabs** — Codex and Claude are always available, each with its own
  glyph, so a disconnected provider can show setup or recovery guidance.
- **Plan in the header** — **Pro**, **Plus**, **Max 20x**, resolved from the
  connected account first and the usage record's plan hint second. It survives
  refreshes and unavailable states because it is account identity, not a property
  of the reading in flight.
- **Per-window rows** — five-hour and weekly usage bars with reset timing.
- **Status pill and "Updated HH:MM:SS"** — freshness at a glance. The header never
  invalidates per second, by design.
- **Token Monitor card** (below).
- **First-run state** — a "connect to get started" card that reuses each provider's
  own sign-in rather than asking for anything new.
- **Footer commands** with fixed key equivalents: Refresh `⌘R`, Notifications
  `⇧⌘N`, Settings `⌘,`, Quit `⌘Q`. One shared catalog supplies both the displayed
  symbol and the registered binding, so the list cannot drift from what actually
  fires.

### Token Monitor

Tokens observed from Codex's and Claude Code's **own local record files** on this
Mac — nothing is uploaded, and producing it spends no tokens.

- **Day or week range**, per provider. The week view charts one bar per elapsed day
  of the *calendar* week your Mac uses, not a rolling seven days, so a
  daylight-saving day stays exactly one bar.
- **Chart**, **per-category totals**, **model shares**, and the **last request**.
- **Independent of quota** — it keeps working while a provider is disconnected.
- **Incremental** — scans on filesystem events and caches reconciled requests
  across launches, so a relaunch shows data before re-reading anything.
- **Per-section toggles** in each agent's Settings page, so you can hide the chart,
  model usage, or the whole card.

### Notifications

- **Remaining Quota thresholds**, configured per agent, with a confirmation
  notification when you change one.
- **Five other warnings**, each individually switchable:

  | Warning | Fires when |
  |---|---|
  | Forecasted exhaustion | The forecast says a window will run out before it resets |
  | Reset-credit expiration | Reset credit is about to lapse |
  | Quota reset or reset failure | A window resets, or fails to |
  | Stale quota data | The displayed reading has aged past the freshness bound |
  | Extended update interruptions | Refreshes have been failing long enough to matter |

- Banners appear **even while the app is focused**.
- Deliveries are deduplicated per provider and per episode, so one problem does not
  produce a stream of notifications.

### Refresh

- **One shared cadence governs every agent**: Automatic, or a fixed 1m30s, 2m, 5m,
  or 10m.
- **Automatic** may temporarily tighten to every 30 seconds near a warning
  threshold, a qualified exhaustion, or a quota reset. Fixed choices never use 30
  seconds.
- **Claude is floored at 5 minutes** even at faster settings, because it reads over
  the network and must stay within Anthropic's limits.
- **After three unsuccessful refreshes**, every mode backs off to a 10-minute retry
  until an update is confirmed.
- **Refresh on wake** is a switch; refreshing on menu open is deliberately not done,
  so opening the popover stays passive.
- Manual refresh is always available from the popover footer.

### Connection control

- **App-local Disconnect** hides a provider's usage in the app at any time
  **without** signing out of its CLI or touching its stored credential. Reconnect
  restores it.
- **External login detection** — if you run `codex login` yourself in Terminal
  while the app shows the disconnected state, it notices within 30 seconds (and
  promptly on app activation) and returns to showing quota, without a relaunch.

## Settings reference

Six destinations, reachable with `⌘,`:

| Page | What lives there |
|---|---|
| **General** | Menu Bar Icon **Style** and **Show**, Remaining/Used, Settings-window **Appearance** (System / Light / Dark), Launch at Login, the keyboard-shortcut toggle and its list, and a full-width menu-bar preview in the context rail |
| **Notifications** | The global permission state, Remaining Quota thresholds, and the five Other Warnings switches |
| **Refresh** | Refresh interval, the effective interval, and Refresh on wake |
| **Agents** | One page per provider — connection (connect / disconnect), quota windows, Token Monitor sections and range, and per-agent warning thresholds |
| **Data & Privacy** | Every file the app writes, with **Reveal in Finder**, **Copy Path**, and **Export Local Data…** (one JSON file; stores that were never written are marked unavailable rather than omitted) |
| **Diagnostics** | Name, version, build, refresh outcome history, **Copy Report**, **Reveal in Finder**, and a confirmed **Clear History…** |

## Privacy and data

- **No prompt, response, source code, or file content is decoded, retained,
  exported, or transmitted.** The Token Monitor reads each bounded JSONL record
  into memory, selectively decodes only usage, model, timestamp, and opaque
  reconciliation fields, then discards the raw bytes.
- **Nothing is uploaded. There is no analytics or telemetry.**
- **Codex** is read from your local Codex CLI's app-server. Choosing "Codex CLI
  sign-in" opens Terminal only when you ask it to. The app never reads `auth.json`,
  tokens, email, or raw provider output.
- **Claude** is read from the OAuth token Claude Code already stored in your
  Keychain (macOS prompts the first time), falling back to a local statusLine
  snapshot and then a local cache. Background refreshes never prompt.
- **Notifications** require macOS notification permission, requested when you enable
  quota alerts.

Everything the app writes lives in `~/Library/Application Support/CodexUsageMonitor`:

| File | Contents | Retention |
|---|---|---|
| `last-known-good.json` | Hashed account identity and normalized quota fields | Replaced by the next confirmed result |
| `quota-history.json` | Confirmed normalized quota observations | 90 days, up to 500 observations |
| `refresh-diagnostics.json` | Timestamps, reasons, classified outcomes, stable failure kinds | 30 days, up to 1,000 outcomes |
| `claude-usage-cache.json` | Normalized Claude percentages, reset times, plan type, extra-usage amount | Replaced by the next fresher reading |
| `claude-rate-limits.json` | Rate-limit percentages and reset times, written by the bundled bridge | Overwritten each time Claude Code renders its status line |
| `token-activity-cache.json` | Hashed request identities, timestamps, models, token counts — no file paths, session identifiers, or record contents | 14 days plus the most recent request |

The app's own **Data & Privacy** page shows this same list live, and can reveal or
export it. See [Data & Privacy verification](docs/claude-usage-verification.md) for
how each path was checked. The signed 0.0.1 page was rechecked for repository
readiness on 2026-07-31; its disclosures remain unchanged and match this list.

## How Claude usage is read, and the terms caveat

Claude usage is read from the **OAuth credential Claude Code already stored in your
Keychain**. macOS asks your permission the first time; background refreshes never
prompt again. Nothing is uploaded. The quota path reads only usage percentages and
reset times; the separate Token Monitor selectively decodes usage metadata from
Claude Code's local records without retaining or transmitting record content.

**Anthropic's Terms of Service do not permit a third-party application to reuse that
credential.** This build does it anyway. That is disclosed here, in the app's **Data
& Privacy** Settings page, and in the release notes rather than buried, so the choice
to install is an informed one. Using it may put your Anthropic account at risk of
enforcement; that risk is yours to weigh. Turning Claude off in **Settings → Agents**
stops the read entirely.

Replacing this with a **first-party OAuth client** — the app requesting its own
authorization instead of borrowing Claude Code's — is the first work planned after
this release. The [credential-methods plan](docs/superpowers/plans/2026-07-21-claude-oauth-web-login-provider.md)
and its [spike findings](docs/superpowers/plans/2026-07-21-claude-oauth-web-login-spike-findings.md)
record what was already tried, including why browser sign-in is shelved as
unverified rather than shipped as working.

Codex usage is read from your local Codex CLI's app-server and carries no such
caveat.

## Roadmap

Status comes from the [product planning board](docs/product/planning-board.md),
which is the authoritative queue. Nothing below is a delivery promise.

### Next

- [ ] **First-party Claude OAuth client** — the app requests its own authorization
      instead of reusing Claude Code's credential. This is what retires the terms
      caveat above.
- [ ] **Popover height** — the tallest Token Monitor state clips on smaller
      displays. Candidate fixes are recorded and none is chosen yet.
- [ ] **Editable keyboard shortcuts** — the four popover commands are currently
      fixed.

### Planned

- [ ] **Dedicated Permissions Settings page** — notification, accessibility, and
      login-item status in one place, each with a direct link to the right macOS
      Settings pane.
- [ ] **Network-aware refresh** — observe connectivity, interface, and
      offline/online transitions; refresh immediately once the network returns
      instead of waiting for the next interval.
- [ ] **Evidence-rich refresh failure explanations** — say *why* a refresh failed,
      with the evidence behind the conclusion, never a guess presented as fact.
- [ ] **Per-provider, per-window warning preferences** — thresholds scoped to a
      single window rather than shared.
- [ ] **Provider identity in notifications.**
- [ ] **Indexed Settings search** with exact-control routing.
- [ ] **Interrupted sign-in recovery** — never get stuck on an in-progress
      connection screen.

### Under research (gated)

- [ ] **GitHub Copilot** — a personal-billing probe found no presentable allowance
      contract. A device-flow route to an undocumented quota endpoint exists but
      depends on another product's OAuth client, which is not acceptable here. An
      explicit architecture decision must approve a product-owned client first.
- [ ] **OpenCode** — its local server can report connected provider IDs but not a
      personal quota; the remaining routes fall outside the privacy boundary.

### Distribution

- [ ] **Sparkle auto-update** with an appcast.
- [ ] **A `.dmg`** with a drag-to-Applications window.
- [ ] **Automated releases** — a GitHub Actions workflow on `v*` tags.

### Deferred by decision

Widgets and a Watch surface, a separate Dashboard window (the popover's Token
Monitor replaced it), a true per-second menu-bar countdown, and distinct
menu-bar disconnected/cache markers. Each keeps its plan; none starts without
explicit direction.

## Known limitations

- **The popover can outgrow a small screen.** With the Token Monitor at its tallest,
  the Codex tab measures about 915 points against roughly 775 usable at 1280×800.
  It does not scroll, by design. Turn off sections you do not need in
  **Settings → Agents → Token Monitor**; hiding the chart saves ~125 points and
  hiding the card entirely returns the tab to ~548.
- **GitHub Copilot is absent, not broken.** No personal-quota API has been verified.
- **Claude's weekly window is shared** with Claude chat, not Claude Code alone.
- **Keyboard shortcuts are not editable yet.** The four assignments are listed in
  **General**.
- **Codex Token Monitor may show no local usage.** This was observed in the
  published release even though Codex had been used locally. The discovery,
  permission, record-schema, and reconciliation paths have not yet been isolated,
  so no cause or workaround is claimed.
- **Claude setup is not yet a dependable first-run flow.** The released setup can
  require extra connection or recovery actions, and the exact failing boundary
  between credential access, passive status-line capture, and explicit CLI recovery
  has not yet been reproduced deterministically.
- **First-launch connection consent is not explicit enough.** A future connection
  change will deliberately start both providers app-locally disconnected on a fresh
  installation and require separate Connect actions before quota collection. It
  must not silently adopt an existing CLI session or let one provider's action
  alter the other.
- **No Dock icon.** It is an `LSUIElement` app; the menu bar is the whole surface.
- **Ad-hoc source builds re-prompt for the Keychain.** An ad-hoc signature's
  designated requirement is pinned to the binary's hash and changes on every build,
  so macOS's "Always Allow" grant does not carry over. Released builds are signed
  with a stable Developer ID identity and do not have this problem.
- **Several surfaces are implemented but not yet visually accepted in a signed
  build.** The planning board's **Verification** rows are the live list.

## FAQ

**Do I need an API key?**
No. The app has no account and no key of its own. It reads sessions the Codex CLI
and Claude Code already created.

**Does it use my quota to check my quota?**
No. Codex reads a local app-server. Claude reads a usage endpoint that does not
consume quota. The Token Monitor reads files already on disk.

**Where did the window go after launch?**
There isn't one. Look at the right end of the menu bar.

**Why is Claude's refresh slower than Codex's?**
Claude reads over the network, so its automatic refresh is floored at 5 minutes to
stay within the provider's limits. Codex's read is local and uses the full range.

**Why does the weekly Claude number look higher than my Claude Code usage?**
The weekly window is shared with Claude chat.

**Can I use it with only one provider?**
Yes. Disconnect the other in **Settings → Agents**; the menu bar and popover adapt.

**Does disconnecting sign me out of the CLI?**
No. Disconnect is app-local only. Your credential is untouched.

**Is it open to contributions?**
Issues are welcome. Agree on implementation scope before opening a pull request;
unsolicited implementation pull requests may not be merged. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Architecture

- **`QuotaViewModel`** is the single state owner the UI observes.
- **`QuotaMonitor`** owns the Codex read cycle; **`ClaudeUsageMonitor`** owns the
  Claude read cycle (OAuth → statusLine → cache). Both run on the one shared
  refresh schedule.
- **`QuotaNotifier`** delivers threshold alerts and confirmations, gated on a single
  notification-permission state and deduplicated per provider.
- **`ClaudeUsageBridge`** is a separate native executable, bundled and signed inside
  the app, that turns a Claude Code statusLine payload into the snapshot the app
  reads. `ClaudeUsageBridgeCore` holds its pure, dependency-free logic so it can be
  tested directly. This works in 0.0.1, but it creates a second nested code object
  that must be built, signed, verified, and notarized with the app.
  [Product Follow-up 10](docs/product/follow-ups.md#10-consolidate-the-claude-usage-bridge-into-the-app-executable)
  plans to give the main app executable a non-UI status-line bridge mode so the
  bundle ships one executable binary while preserving the same stdin, privacy,
  installation, and failure contracts.
- **`AppSettings`** persists preferences; **`LocalDataInventory`** is the single
  declaration of every file the app writes, and both the Data & Privacy page and the
  export action read from it.

Repository-wide invariants — Settings geometry, selection-host guardrails, native
menu update rules, and the testing policy — live in [AGENTS.md](AGENTS.md).

## Development

```sh
cd CodexUsageMonitor
swift build
swift test
```

- `Scripts/build-app.sh` — bundle, compile assets, build the `.icns`, sign
  inside-out. Set `BUILD_CONFIGURATION=debug` for local iteration only.
- `Scripts/verify-signed-app-resources.sh` — confirm the compiled asset catalog and
  the bridge are actually inside the signed bundle.
- `UsageProbe/` — the read-only research probe used to verify provider endpoints
  before any adapter was written. See its own README.

Testing policy: automated coverage is added for **reproducible defects** — the
smallest deterministic regression test that fails against the old behavior and
passes against the fix. Feature-presence and happy-path tests are deliberately not
added. See [AGENTS.md](AGENTS.md#documentation-discipline).

Releases follow [docs/development/releasing-on-github.md](docs/development/releasing-on-github.md),
and pull requests follow the
[evidence-rich PR contract](docs/development/evidence-rich-pull-requests.md).

## Documentation

| Document | What it covers |
|---|---|
| [Product planning board](docs/product/planning-board.md) | Authoritative status of every feature, fix, and release gate |
| [Product follow-ups](docs/product/follow-ups.md) | The detailed problem statements behind the board |
| [Release notes](docs/release-notes/) | Per-version notes |
| [Releasing on GitHub](docs/development/releasing-on-github.md) | Signing, notarization, tagging, publishing |
| [Before going public](docs/development/before-going-public.md) | What still needs to change before the repository is made public |
| [AGENTS.md](AGENTS.md) | Durable repository invariants and guardrails |
| [CONTEXT.md](CONTEXT.md) | Canonical vocabulary for the app's UI regions |
| [Data & Privacy verification](docs/claude-usage-verification.md) | How each Claude read path was verified |
| [Notification warnings](docs/development/notification-warnings.md) | What each Other Warnings toggle does and when it fires |
| [Authentication and usage collection](docs/development/authentication-and-usage-collection.md) | The provider read paths in detail |
| [Popover spec](docs/design/menu-bar-popover/SPEC.md) | The menu-bar popover design contract |
| [Implementation plans](docs/superpowers/plans/) | The full design and evidence trail |
| [Operating notes](docs/development/operating-notes.md) | Maintainer notes for the login flow, the usage probe, and running the app from source |
| [Contributing](CONTRIBUTING.md) | Issue, privacy, regression-test, and pull-request expectations |
| [Security policy](SECURITY.md) | Private vulnerability-reporting guidance |

## Acknowledgements

AgentUsageMonitor's product ideas, provider research, and local-usage architecture
were informed by these open-source GitHub projects:

- [CodexBar](https://github.com/steipete/CodexBar) — native macOS menu-bar,
  provider-separation, packaging, and quota-retrieval reference.
- [ccusage](https://github.com/ccusage/ccusage) — local usage parsing, fixtures,
  reporting, and adapter-boundary reference.
- [Token Monitor](https://github.com/Javis603/token-monitor) — local collector,
  aggregation, privacy, performance, and product-surface reference.
- [Tokscale](https://github.com/junhoyeo/tokscale) — multi-agent source discovery,
  token scanning, and structured-output comparison reference.

Thank you to their maintainers and contributors for publishing work that helped
shape this project's ideas and provided independent comparison points. These
projects are credited as inspiration and research references; they are not bundled
runtime dependencies, and this acknowledgement does not imply their endorsement
or a direct code contribution. The detailed research links remain in
[RESOURCES.md](RESOURCES.md).

## License

The source code in this repository is available under the
[MIT License](LICENSE).

The MIT License covers this project's source and documentation. It does not grant
rights to provider services, credentials, names, logos, or other marks, and it does
not override OpenAI, Anthropic, GitHub, Apple, or other third-party terms.

AgentUsageMonitor is an independent project and is not affiliated with, endorsed
by, or supported by OpenAI, Anthropic, GitHub, or Apple. Provider names and marks
belong to their respective owners.
