# Claude Usage Monitor Source Audit — 2026-08-26

Revalidated against the source-pinned public implementations and the locally
installed Claude Code 2.1.247 on 2026-08-28. Corrected on 2026-08-29 after a
direct CLI run proved setup-token completion but the issued token still lacked
the scope required by the usage endpoint.

## Straight answer for Agent Usage Monitor

CodexBar and the reviewed token-monitor apps are not obtaining live Claude
account quota through a permission-free OAuth login. When they appear to work
without setup, they are relying on state Claude Code already created, or on data
Claude Code hands them locally:

- **CodexBar** prefers the OAuth usage endpoint, but its credential comes from
  CodexBar's own cache, Claude's credential file, or Claude Code's Keychain item.
  Its sign-in action runs `claude auth login --claudeai` in a PTY and waits for
  Claude CLI to finish; it does not implement an independent third-party OAuth
  client.
- **Javis603/token-monitor** discovers an environment credential, credential
  file, Windows credential, or macOS Keychain item. On macOS it asks Claude CLI
  to refresh that borrowed credential and can drive `/usage` through a PTY.
- **soulduse/ai-token-monitor** explicitly shells out to `/usr/bin/security` to
  read Claude Code's Keychain entries, falls back to `.credentials.json`, and
  runs `claude auth status --json` for refresh. This is Keychain access even if
  a particular machine does not show a prompt.
- **young1lin/claude-token-monitor** has the one genuinely credential-free quota
  path: it consumes `rate_limits` from Claude Code's status-line stdin. It still
  optionally reads `.credentials.json` for a plan label and falls back to OAuth
  when `rate_limits` is absent.
- **rjwalters/claude-monitor** asks for a long-lived token produced by
  `claude setup-token`; it does not automate a hidden OAuth flow.

That maps directly to the architecture already chosen here:

| Competitor technique | Agent Usage Monitor equivalent | Decision |
|---|---|---|
| Status-line `rate_limits` | Passive Claude Usage Snapshot | Keep first; this is the zero-secret fast path |
| App-owned setup token | App-Owned Claude Credential | Reject for quota; the issued inference token lacks `user:profile` |
| Borrow Claude Code credential | Claude Code Credentials connection action | Keep explicit; authoritative OAuth after consent |
| PTY `/usage` | Forced Claude Usage Read | Keep user-initiated; never schedule it |
| CLI-owned browser login | Claude Code's existing login | Direct the user to Claude Code; do not automate setup-token for quota |
| Direct OAuth with Claude Code's client ID | None | Reject unless Anthropic publishes a third-party contract |

The stuck in-app setup exposed lifecycle defects, but those defects are no
longer the product boundary. On 2026-08-29 the user ran `claude setup-token`
directly: Claude Code completed authorization, printed a one-year token, and
exited 0. That successful token is still not a quota credential because it lacks
`user:profile`. No callback or capture repair can add a scope the provider did
not issue.

## Conclusion

The comparable apps do not reveal a hidden, permission-free OAuth mechanism.
They use one or more of these sources:

1. Claude Code's credential file or macOS Keychain item.
2. An app-owned long-lived token created by `claude setup-token` (inference, not
   a verified usage-endpoint credential).
3. A Claude CLI command such as `/status` or `/usage`.
4. Claude Code's status-line JSON, whose documented `rate_limits` field contains
   the five-hour and seven-day quota windows without exposing a credential.

Only item 4 is genuinely zero-secret and zero-Keychain. It is event-driven: the
field is available after Claude Code receives an API response, so it is an
excellent freshness fast path but not a guaranteed on-demand account read.

## Sources inspected

The repository revisions below were inspected locally. No credential values
were read or recorded.

| Project | Revision | What it actually does | Access-free? |
|---|---|---|---|
| [CodexBar](https://github.com/steipete/CodexBar/blob/cf79d1310493f2d028af62cc21e422b5f33c70a5/docs/claude.md) | `cf79d1310493f2d028af62cc21e422b5f33c70a5` | Tries OAuth, Claude CLI, then web. Its OAuth credential comes from CodexBar's own Keychain cache, Claude's credential file, or Claude Code's Keychain item. Its login runner delegates the browser flow to `claude auth login --claudeai`. | No |
| [Javis603/token-monitor](https://github.com/Javis603/token-monitor/blob/3e80f82b19c41c2ed452c0794025337fc31752d2/src/shared/limitCollector.js) | `3e80f82b19c41c2ed452c0794025337fc31752d2` | Reads an environment credential, credential file, Windows Credential Manager, or macOS Keychain. On macOS it delegates refresh to Claude CLI and falls back to a PTY-driven `/usage` read. | No |
| [soulduse/ai-token-monitor](https://github.com/soulduse/ai-token-monitor/blob/3597ad179265c5d9f67e3ffbc178f1973ff3cbc0/src-tauri/src/oauth_usage.rs) | `3597ad179265c5d9f67e3ffbc178f1973ff3cbc0` | Reads Claude Code's macOS Keychain item or credential file and delegates refresh to `claude auth status --json`. | No |
| [young1lin/claude-token-monitor](https://github.com/young1lin/claude-token-monitor/blob/df03cafa96a5a30ccad7a7ef8f55b7fc3d8d86c4/internal/statusline/content/quota_anthropic.go) | `df03cafa96a5a30ccad7a7ef8f55b7fc3d8d86c4` | Consumes `rate_limits` from Claude Code's status-line stdin and does not need a credential for that reading. | Yes, for event-driven readings |
| [rjwalters/claude-monitor](https://github.com/rjwalters/claude-monitor/tree/dceedec2635a16db624d1c9ebde893f49773f94b) | `dceedec2635a16db624d1c9ebde893f49773f94b` | Asks the user to run `claude setup-token` and provide the resulting long-lived token. | No, but the app can own the resulting credential |

Anthropic's [status-line documentation](https://code.claude.com/docs/en/statusline)
documents the `rate_limits.five_hour` and `rate_limits.seven_day` fields, including
reset timestamps. It also says the field is available only after the first API
response and for Claude.ai subscribers. Anthropic's
[usage-limit guidance](https://code.claude.com/docs/en/errors) documents `/usage`
as the interactive command for viewing current limits.

## Findings

### F1 — Shelling out to `security` does not remove Keychain authorization

Severity: High for the proposed prompt-free experience.

The `security` process still asks macOS to read Claude Code's Keychain item. It
does not bypass that item's access control and can still cause a system prompt.
CodexBar keeps this reader experimental and does not use it as a general escape
hatch. Agent Usage Monitor must not describe this as permission-free.

### F2 — Reusing Claude Code's OAuth client is not an independent app login

Severity: High for correctness and user trust.

The direct PKCE examples found in this ecosystem reuse Claude Code's public
client identifier and private/undocumented service endpoints. The consent flow
therefore identifies Claude Code rather than Agent Usage Monitor, and the local
July spike never completed the authorization-code exchange because it received
429 responses. This is not an acceptable production primary path unless
Anthropic publishes a third-party authorization contract or issues this app its
own client registration.

### F3 — Status-line capture is the only verified zero-secret source

Severity: Informational; this is the preferred fast path.

The status-line payload is generated by Claude Code after semantic events. A
fresh snapshot can be served before any credential lookup, network request, or
Keychain access. Its limitation is availability: before the first qualifying
Claude response, or while Claude Code is idle, it may be absent or stale.

### F4 — `claude setup-token` does not create a viable quota credential

Severity: High for correctness.

The installed Claude Code 2.1.247 advertises `setup-token` as a long-lived token
flow and the user's direct run completed successfully. Inspection of the
installed CLI and the endpoint result establish that environment/setup-token
sessions default to inference scope; `/api/oauth/usage` requires
`user:profile`. Public Anthropic issue reports
[#22450](https://github.com/anthropics/claude-code/issues/22450) and
[#81015](https://github.com/anthropics/claude-code/issues/81015) document the
same 403 scope boundary. Retrying the browser flow, extending the callback
listener, or capturing the token differently cannot make it authoritative for
quota.

## Approved two-stage source policy

### Stage 1 — Normal operation

1. Serve a fresh status-line `rate_limits` snapshot without touching any
   credential source.
2. When an authoritative read is needed, use the explicitly authorized Claude
   Code Keychain credential with interaction forbidden on automatic refreshes.
3. If neither can serve, show the last cache with its source and age. Do not
   prompt, run `/usage`, or read a credential file silently.

### Stage 2 — Explicit recovery

1. `Force read with Claude /usage` launches Claude CLI and parses the displayed
   limits. It is user-initiated, because it may consume a Claude turn. Keep the
   current `claude -p /usage` runner while it remains verified; move it to a PTY
   only if a real CLI version proves the non-interactive output insufficient.
2. `Reconnect Claude` is the separately disclosed Keychain action. Its
   cross-app read may prompt only because the user pressed it; later automatic
   reads use the stored macOS grant without interaction.

As of 2026-08-26, `ClaudeCompositeCredentialStore` no longer tries an alternate
credential method automatically. The chosen method remains observable, and a
failure degrades to passive data/cache plus an explicit recovery action.

## Implementation gates

- Remove setup-token enrollment and clean only the obsolete app-owned item.
- Keep borrowed credential reads actor-isolated, memory-only, non-printable,
  and explicitly non-interactive outside Connect/Reconnect.
- Prove the one-time Keychain grant, relaunch, non-interactive read, and
  app-local Disconnect with the signed app.
- Put the passive freshness check before construction or invocation of any
  credential reader.
- Keep `/usage` behind its distinct, explicit user action; a Keychain failure
  must never cascade into it.
- Do not ship direct PKCE using Claude Code's client identity.

## Current setup-token callback boundary — 2026-08-28

Superseded on 2026-08-29. The history below explains the failed automation but
is no longer an implementation gate because a direct successful CLI run proved
the issued token lacks quota scope.

`ClaudeSetupTokenCapture` launches `claude setup-token` with stdin, stdout, and
stderr attached to an app-owned PTY. The child process owns the browser flow and
localhost listener. The 2026-08-28 repair races that session against a bounded
20-minute authorization deadline; timeout terminates the process and closes the PTY.
The app reads the PTY but does not provide interactive input.

The first-ranked hypothesis for the reported email-verification case was that the
five-minute deadline expired before the browser returned, leaving no listener at
the callback address. This is supported by the source but not behaviorally
proven because elapsed time and child-listener state were not recorded. Other
ranked hypotheses are a listener bind failure, a browser/device mismatch, an
upstream Claude CLI callback regression, and a post-token app-state transition
failure. The implementation plan begins with a structured live evidence gate to
distinguish them; it must never log the authorization URL, callback query, code,
state, token, or raw terminal output.

Claude Code 2.1.247 exposes no documented `setup-token` flag for device-code
authentication, noninteractive completion, or callback forwarding. Do not add a
"paste callback URL" feature unless a live capability check first proves that
the CLI accepts that input. Keep the callback exchange owned by Claude CLI.
