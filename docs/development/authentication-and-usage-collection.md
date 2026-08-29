# Authentication and usage collection

Agent Monitor does not operate an account service. Provider authentication
stays owned by the official local CLI; the app reads the minimum provider state
needed to show quota after the user enrolls that provider.

## Enrollment and disconnect

Codex and Claude begin app-locally disconnected. Each provider requires its own
Connect action before Agent Monitor checks the account, reads quota, or scans
local activity. Existing CLI login state does not silently enroll a provider.

Disconnect is local to Agent Monitor. It stops that provider's monitors and
removes app-owned derived data. It does not sign out the provider CLI or delete
provider-owned credentials.

## Codex

Codex authentication and quota are read through the local Codex app-server.
Browser sign-in uses the provider-generated URL and completion event. CLI sign-in
opens the located `codex login` command visibly. Agent Monitor never reads or
stores `auth.json` or a Codex token.

Quota refresh uses read-only account and rate-limit methods. Confirmed normalized
results may be cached under Application Support; raw responses and credentials
are not retained.

## Claude

### Source order

Automatic Claude collection has one source policy:

1. Serve a usable status-line snapshot captured within two minutes. This
   performs no Keychain read, network request, or Claude CLI launch.
2. Read Claude Code's existing Keychain credential with the prompt policy for
   the refresh reason and call `GET /api/oauth/usage`.
3. Fall back to the fresher of an older status-line snapshot and the last known
   good normalized OAuth result.

`claude -p /usage` is not in the automatic hierarchy. It can consume a small
amount of quota and runs only from the separately disclosed **Force Read** action.

### One Connect action

**Connect Claude** performs two disclosed app-local enrollment steps:

- it installs Agent Monitor's privacy-scoped status-line command when Claude
  Code has no status line; a working foreign command is never replaced; and
- it reads Claude Code's existing OAuth credential once with user interaction
  allowed, validates `user:profile`, and proves the connection with a successful
  usage response.

macOS prompts because Claude Code and Agent Monitor are different signed
applications. Choosing **Always Allow** permits later scheduled reads. Choosing
**Allow** permits only that read; automatic refreshes never display the prompt
and instead degrade to passive capture or cache.

There is no setup-token route or credential-method fallback. Claude Code
2.1.247 successfully created a one-year `setup-token`, but that inference token
does not carry the `user:profile` scope required by the usage endpoint. The
obsolete app-owned Keychain item (`AgentUsageMonitor-ClaudeOAuth`, account
`setup-token-v1`) is deleted by an idempotent migration.

### Credential boundary

`ClaudeKeychainCredentialStore` is an actor. Its secret-bearing Keychain read
runs outside `@MainActor`; scheduled reads attach an `LAContext` with interaction
disabled. The access token is deliberately non-`Codable` and non-printable,
exists only in memory for the request, and is never cached, logged, exported,
refreshed directly, changed, or deleted.

The provider-owned item uses Claude Code's compatible login-Keychain lookup.
Agent Monitor does not migrate it into the data-protection keychain. The one
delete query owned by this app targets only the retired setup-token service and
account and includes data-protection routing.

On an unauthorized response, automatic refresh does not launch Claude Code.
The delegated `claude auth status --json` renewal check remains user-initiated
and single-flight until scheduled behavior passes its separate capability gate.
Its output is discarded and success requires the non-secret Keychain
modification date to change before one non-interactive retry.

### Passive capture and single executable

Claude Code pipes its official status-line JSON to Agent Monitor's command. The
bridge extracts only:

- `rate_limits.five_hour.used_percentage`
- `rate_limits.five_hour.resets_at`
- `rate_limits.seven_day.used_percentage`
- `rate_limits.seven_day.resets_at`

No prompts, responses, paths, model names, session identifiers, or other payload
fields are retained.

The app bundle contains one compiled executable. An atomic app-owned symlink to
the signed main Mach-O uses the stable path
`~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/claude-usage-bridge`.
When invoked under that basename, the process enters bridge mode before creating
SwiftUI/AppKit state, reads stdin, writes the normalized snapshot, and exits.

Disconnect removes only the exact managed status-line entry, bridge symlink,
passive snapshot, normalized cache, and enrollment state. A changed or foreign
status line is preserved.

## Security and product caveat

Anthropic does not publish `/api/oauth/usage` or reuse of Claude Code's OAuth
credential as a third-party application contract. This is a compatibility
boundary and may carry account-enforcement risk. A first-party Agent Monitor
OAuth client would supersede it if Anthropic offers a supported contract.

The durable decision and alternatives are recorded in
[ADR 0002](../adr/0002-claude-usage-auth-and-bridge-boundaries.md).

## Summary

| Boundary | Codex | Claude |
|---|---|---|
| Credential owner | Codex CLI | Claude Code |
| App token storage | none | none |
| First connection | explicit provider enrollment | explicit enrollment plus possible Keychain prompt |
| Scheduled prompt | never | never |
| Passive source | local app-server state | status-line `rate_limits` |
| Manual recovery | provider sign-in / refresh | cost-disclosed `/usage` |
| Disconnect changes provider login | no | no |
