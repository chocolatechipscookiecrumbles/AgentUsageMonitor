# ADR 0002: Claude usage authentication and bridge boundaries

- Status: Accepted
- Date: 2026-08-29

## Context

Claude Code 2.1.247 can complete `claude setup-token`, but the resulting
long-lived inference token does not provide the `user:profile` scope required
by `GET /api/oauth/usage`. Callback or PTY changes cannot repair a scope the
provider did not issue. Claude Code's own OAuth credential is confirmed to work
when macOS grants this app read access. Claude Code also supplies field-scoped
`rate_limits` values to its status-line process without exposing a credential.

The released app shipped a second executable for status-line capture. That
helper duplicated signing and packaging work even though its parsing and file
format were already isolated in `ClaudeUsageBridgeCore`.

## Decision

Claude usage uses this order:

1. A status-line snapshot captured within two minutes, requiring no credential
   or network request.
2. Claude Code's existing Keychain credential and `GET /api/oauth/usage`.
3. The freshest older status-line snapshot or cached successful OAuth result.
4. Manual, cost-disclosed `claude -p /usage` only when the user chooses it.

There is one **Connect Claude** action. It records app-local enrollment, installs
passive capture only when no working third-party status line would be replaced,
and performs one user-initiated Keychain read. The UI instructs the user to
choose **Always Allow** for unattended refresh. Scheduled reads use a
non-interactive `LAContext` and never prompt.

The Claude Code credential remains provider-owned. This app reads it in memory
for one request and never stores, mirrors, refreshes directly, edits, exports,
or deletes it. The borrowed item intentionally uses Claude Code's compatible
login-Keychain lookup rather than forcing data-protection-keychain routing;
changing that query can make the provider-owned item undiscoverable. The only
Keychain deletion is the exact app-owned setup-token item from the retired
experiment.

The app target is the only compiled executable product. At runtime, an atomic
app-owned symlink named `claude-usage-bridge` points to the signed Mach-O inside
the app bundle. Copying the executable itself was rejected because the main
signature includes the bundle's Info.plist slot and fails strict validation when
the binary is removed from that bundle.
Dispatch by that basename enters a synchronous bridge path before SwiftUI,
AppKit, notifications, monitors, Keychain reads, or network clients are
constructed. The stable filename preserves existing configuration and rollback
compatibility.

Disconnect is app-local: it immediately disables Claude monitoring and removes
the exact managed status-line entry, bridge symlink, passive snapshot, and usage
cache. It does not sign out Claude Code or change its credential. A foreign
status line is always preserved.

## Consequences

- Initial connection can require one explicit macOS Keychain decision; a true
  zero-input first run is not possible.
- Steady-state refresh is unattended only after **Always Allow**. If permission
  is absent, automatic reads fail closed to passive capture/cache.
- Setup-token callback, method selection, and app-owned token storage are
  removed.
- The app bundle contains one Mach-O, while Application Support contains only a
  stable symlink to that signed bundle executable.
- Direct use of Anthropic's private usage endpoint and Claude Code credential is
  a compatibility boundary, not a published third-party OAuth contract.
- Delegated Claude CLI renewal stays user-initiated until a separate capability
  check proves that scheduled renewal is safe and effective.
