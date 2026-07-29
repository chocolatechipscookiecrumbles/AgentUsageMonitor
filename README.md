# Codex Usage Monitor

**Your Codex and Claude Code usage limits, in the macOS menu bar.**

Codex Usage Monitor is a lightweight macOS menu-bar app that shows how much of your
AI coding usage is left — the five-hour and weekly limits for **OpenAI Codex** and
**Claude Code** — with reset countdowns, a per-provider popover, and optional quota
notifications. It reads sessions you already have on your machine; it never asks for
a password and never sends your prompts, responses, or code anywhere.

> Requirements: macOS 14+. Non-commercial. **Claude support reuses Claude Code's own
> Keychain credential, which Anthropic's Terms of Service do not permit** — read
> [how Claude usage is read](#how-claude-usage-is-read-and-the-terms-caveat) before
> installing.

## Why

Codex and Claude both meter usage across rolling windows, but neither surfaces "how
much is left and when it resets" at a glance. This app puts that in the menu bar,
adds threshold alerts before you run out, and keeps each provider's connection and
warnings on its own page — without a browser extension, a login, or your data
leaving the machine.

## Providers and data sources

| Provider | Source | Reads | Leaves your machine |
| --- | --- | --- | --- |
| **OpenAI Codex** | Local Codex CLI app-server | Your existing Codex CLI session's usage | No |
| **Claude Code** | OAuth token in Claude Code's Keychain → statusLine snapshot → local cache | Five-hour and weekly usage | No |
| GitHub Copilot | — | Not yet supported (capability gated) | — |

Both providers reuse a session you already established with the provider's own tool.
The app adds no new account, network login, or credential of its own.

## Features

- **Menu-bar readout** with text or 34-point graphical quota bars. The graphical
  choices include per-provider stacked or combined windows and a two-bar
  single-provider layout when exactly one provider is connected.
- **Multi-provider popover** with Codex and Claude tabs — per-window usage bars,
  reset timing, cached-vs-confirmed freshness, and a first-run "connect to get
  started" state that reuses each provider's own sign-in.
- **Per-agent Settings** — each agent has its own page: connection (connect /
  disconnect), quota windows, and its own **Remaining Quota** warning thresholds.
- **Notifications** — quota threshold alerts per agent, plus a confirmation when you
  change a threshold. Notifications appear as banners even while the app is focused.
- **One shared refresh cadence** governs every agent. Claude reads over the network,
  so its automatic refresh is floored (never faster than every 5 minutes) to stay
  within the provider's limits; Codex's local read uses the full range.
- **App-local disconnect** — hide a provider's usage in the app at any time without
  signing out of its CLI or touching its stored credential.

## Install

Download the `.app` from the [latest release](../../releases/latest), unzip it, and
move it to `/Applications`. It launches into the **menu bar** — there is no Dock
icon. Or build it from source:

```sh
# Build and run the checks
cd CodexUsageMonitor
swift build
swift test

# Build the signed .app bundle
./Scripts/build-app.sh
```

`build-app.sh` produces the `.app`; `Scripts/verify-signed-app-resources.sh` checks
the bundled resources. Launch the built app and it appears in the menu bar (it is a
menu-bar-only `LSUIElement` app — no Dock icon by default).

## Privacy and permissions

- **No prompt, response, source code, or file content is read or transmitted.** The
  app reads only usage/limit numbers and reset times.
- **Codex** is read from your local Codex CLI's app-server. Choosing "Codex CLI
  sign-in" opens Terminal only when you ask it to.
- **Claude** is read from the OAuth token Claude Code already stored in your Keychain
  (macOS prompts for permission the first time), falling back to a local statusLine
  snapshot and then a local cache. Background refreshes never prompt.
- **Notifications** require macOS notification permission, requested when you enable
  quota alerts.
- Nothing is uploaded; there is no analytics or telemetry.

See [Data & Privacy](docs/claude-usage-verification.md) and the app's own **Data &
Privacy** Settings page for specifics.

## Architecture

- `QuotaViewModel` is the single state owner the UI observes.
- `QuotaMonitor` owns the Codex read cycle; `ClaudeUsageMonitor` owns the Claude
  read cycle (OAuth → statusLine → cache), each on the shared refresh schedule.
- `QuotaNotifier` delivers threshold alerts and confirmations, gated on one
  notification-permission state and deduplicated per provider.
- Preferences persist in `AppSettings`.

## Documentation

- [How-to](how-to.md) — user-facing behavior and operations.
- [AGENTS.md](AGENTS.md) — durable repository invariants and guardrails.
- [Product planning board](docs/product/planning-board.md) — status of every feature
  and fix.
- [Evidence-rich pull requests](docs/development/evidence-rich-pull-requests.md) —
  the repository's PR contract.
- [Notification warnings](docs/development/notification-warnings.md) — what each
  "Other Warnings" toggle does and how it fires.
- [Implementation plans](docs/superpowers/plans/) — the design and evidence trail.

## How Claude usage is read, and the terms caveat

Read this before installing.

Claude usage is read from the **OAuth credential Claude Code already stored in your
Keychain**. macOS asks your permission the first time; background refreshes never
prompt again. Nothing is uploaded, and no prompt, response, or file content is ever
read — only usage percentages and reset times.

**Anthropic's Terms of Service do not permit a third-party application to reuse that
credential.** This build does it anyway. That is disclosed here, in the app's **Data
& Privacy** Settings page, and in the release notes rather than buried, so the choice
to install is an informed one. Using it may put your Anthropic account at risk of
enforcement; that risk is yours to weigh.

Replacing this with a **first-party OAuth client** — the app requesting its own
authorization instead of borrowing Claude Code's — is the first work planned after
this release. The [credential-methods plan](docs/superpowers/plans/2026-07-21-claude-oauth-web-login-provider.md)
and its [spike findings](docs/superpowers/plans/2026-07-21-claude-oauth-web-login-spike-findings.md)
record what was already tried.

Codex usage is read from your local Codex CLI's app-server and carries no such
caveat. GitHub Copilot is unsupported: no personal-quota API has been verified, and
it stays gated behind its own capability review.

This build is **non-commercial**.
