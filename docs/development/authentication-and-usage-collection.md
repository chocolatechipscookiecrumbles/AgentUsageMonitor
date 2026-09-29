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

1. Serve a valid status-line snapshot with at least one quota window captured
   no more than two minutes ago. This performs no Keychain read, network request,
   or Claude CLI launch.
2. Silently read Claude Code's existing Keychain credential and call
   `GET /api/oauth/usage`, subject to existing rate-limit backoff.
3. Fall back to the freshest usable older status-line snapshot or cached
   reading, retaining its original capture time.
4. With no usable reading, show unavailable usage and explicit recovery actions.

Launch, scheduled refresh, menu opening, ordinary Refresh, and retries never
permit Keychain interaction. Only explicit Connect/Reconnect may prompt.

`claude -p /usage` is not in the automatic hierarchy. It can consume a small
amount of quota and runs only from the separately disclosed **Force Read** action.

Fresh passive readings and successful explicit `/usage` readings are eligible
for quota-threshold evaluation when each window carries a future reset time.
Passive eligibility uses the same two-minute freshness boundary as collection;
retained cached readings never trigger a new threshold alert. `/usage` reset
text uses its reported timezone when present. If a reset cannot be parsed, the
percentage remains usable but that window cannot alert because it has no stable
reset-window identity.

Permitted automatic sources do not currently expose Claude redeemable-reset
inventory or a prepaid usage-credit balance. Settings reports those values as
**Unavailable** and links to Claude Usage. OAuth `extra_usage` remains the source
for reported usage-credit spending and an optional monthly spending limit;
missing amount or currency is never converted to zero or USD. Its observation
time remains separate when a newer passive or explicit CLI quota reading is displayed.

### One Connect action

**Connect Claude** performs two disclosed app-local enrollment steps:

- it installs Agent Monitor's privacy-scoped status-line command when Claude
  Code has no status line; a working foreign command is never replaced; and
- it reads Claude Code's existing OAuth credential once with user interaction
  allowed, validates `user:profile`, and attempts a live usage response.

Enrollment means **Monitoring enabled**, independently of live OAuth availability.
If credential authorization is denied, cancelled, or unavailable, passive
monitoring resumes; enrollment and usable quota readings remain intact. Explicit
Reconnect remains available without becoming a prerequisite for showing usage.

macOS prompts because Claude Code and Agent Monitor are different signed
applications. **Always Allow** is intended to authorize subsequent reads, but
its durability for this provider-owned item is not guaranteed. **Allow** permits
only that read. Background failures are **Live fallback unavailable**, not
evidence that permission was revoked, and collection falls back to passive
capture or cache without another dialog. Repeated prompts are tracked in the
separate [grant-durability diagnosis](claude-keychain-grant-durability.md); that
investigation does not gate passive-first monitoring.

There is no setup-token route or credential-method fallback. Claude Code
2.1.247 successfully created a one-year `setup-token`, but that inference token
does not carry the `user:profile` scope required by the usage endpoint. The
obsolete app-owned Keychain item (`AgentUsageMonitor-ClaudeOAuth`, account
`setup-token-v1`) is deleted by an idempotent migration.

### Credential boundary

`ClaudeKeychainCredentialStore` is an actor. Its secret-bearing Keychain read
runs outside `@MainActor`. Because the legacy Keychain path does not consume
`LAContext`, a shared lock serializes both read policies. Silent reads save the
process-local legacy interaction setting, disable interaction, perform the scoped
read, and restore the previous setting with every status checked. The query also
attaches a noninteractive `LAContext`; that context alone is not the legacy UI
guard. The deprecated `SecKeychainGetUserInteractionAllowed`,
`SecKeychainSetUserInteractionAllowed`, and `SecKeychainCopyDefault` APIs are kept
only at this compatibility boundary. See [Apple's legacy SecItem implementation](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_keychain/lib/SecItem.cpp).
 The access token is deliberately non-`Codable` and non-printable,
exists only in memory for the request, and is never cached, logged, exported,
refreshed directly, changed, or deleted.

The provider-owned item uses Claude Code's compatible legacy Keychain lookup,
scoped to the single default/login Keychain instead of the global search list.
Agent Monitor never changes that list or the item's access permissions and does
not migrate it into the data-protection keychain. The one delete query owned by
this app targets only the retired setup-token service and
account and includes data-protection routing.

Typed credential failures remain intact through the OAuth layer. Neither an
expired token nor an unauthorized response launches Claude Code during ordinary
Refresh or automatic collection. Delegated CLI renewal is removed. Only the
explicit, consented `/usage` recovery action launches the CLI for usage; it
prevents duplicate execution, publishes and caches a successful result, and
retains the previous reading on failure.

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
