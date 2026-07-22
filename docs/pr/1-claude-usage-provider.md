# PR 1 — Claude usage provider

**Branch:** `feature/claude-usage-provider` → `main`
**Merge first** — PRs 2 and 3 both build on this.

## What this does

Makes Claude Code a real, user-reachable usage provider instead of a static preview, and hardens the credential path it depends on.

Claude usage now reads live through a four-tier hierarchy and is visible on its own Settings page, built on the same shared components as Codex.

## Source hierarchy

| Tier | Source | Status |
|---|---|---|
| 1 | **OAuth** — via Claude Code credentials (Keychain) | live, working |
| 2 | **CLI `/usage` probe** | built, **manual only** — costs tokens |
| 3 | statusLine passive capture | live |
| 4 | cached last-known-good | live |

Verified live against a Pro account: `plan pro · 5h 44% · 7d 28% · delivery live/oauth`.

## Notable decisions

**Tier 2 is deliberately not automatic.** Anthropic documents that `/usage` consumes tokens (~$0.04/session). Putting it in the scheduled fallback order would spend quota to measure quota, precisely when OAuth is already failing. It sits behind a button with the cost stated in a footnote and a first-use confirmation prompt; consent defaults to false.

**Background refreshes can no longer raise a Keychain prompt.** `KeychainPromptPolicy` maps every automatic reason to `.never`, which sets `kSecUseAuthenticationUIFail`; only `.userInitiated` may prompt. A denied read degrades to the next tier instead of erroring.

**Browser sign-in (`claude setup-token`) is shelved as unverified, not shipped.** A live attempt returned 401, but the control endpoint also 401'd, so the result proves nothing either way. It is implemented and unit-tested but wired to nothing, and must not be presented as working. See the [spike findings addendum](docs/superpowers/plans/2026-07-21-claude-oauth-web-login-spike-findings.md).

## Bugs found and fixed

- **The cache decayed instead of preserving the best reading.** A degraded refresh overwrote a current OAuth read (5h 44%) with a 47-hour-old statusLine capture (5h 5%). `save` now refuses to replace newer data with older, and the collector ranks tier 3 vs 4 by capture time rather than assuming statusLine is fresher.
- **`start()` could not be cancelled.** The launch refresh ran even when `stop()` was called immediately after.
- **The app signed ad-hoc**, so its designated requirement was pinned to a cdhash that changed every build — silently invalidating "Always Allow" each rebuild. Now signs with the Developer ID identity.
- **`~/.local/bin/claude` was not a locator candidate**, and a GUI `.app` does not inherit the login shell's `PATH`.

## Testing

168 tests (44 baseline → 168). App verified to launch. Manual verification guide: [docs/claude-usage-verification.md](docs/claude-usage-verification.md).

## Not done

- The Settings UI has had no human click-through — button states, disconnect, and failure copy are covered by tests but unexercised by hand.
- The tier-2 parser is tested against synthetic fixtures; its real `/usage` output format is **unverified**, since confirming it costs tokens.
