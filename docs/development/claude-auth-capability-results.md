# Claude setup-token capability results

Status: **setup-token rejected for quota; Claude Code Keychain confirmed**

Date: 2026-08-28

Branch: `feat/claude-setup-token-primary`

This record must never contain an account email, organization, token, response body, raw CLI output, or Keychain item data.

## Environment

- macOS version: not recorded; user acceptance pending
- Claude CLI version: 2.1.247, reported by the user
- release app assembly: `Scripts/build-app.sh` exited successfully on 2026-08-28
  and reported `Developer ID Application`, but an independent
  `codesign --verify --deep --strict` rejected both bundled executables as
  modified; signing acceptance is therefore failed/pending, and the app was not
  launched or behaviorally exercised

## Capture

Implemented with a cancellable PTY, an 8 KiB in-memory bound, a 20-minute
authorization deadline, and token-only parsing. The UI exposes only non-secret
waiting, validating, and saving phases and offers a setup-only Cancel action.
Live signed-app capture is unverified.

User observation on 2026-08-26: Claude Code completed email verification and displayed its connected state, but Agent Monitor remained disconnected. Root cause was the PTY capture waiting for CLI EOF after it had already isolated a complete token. The capture now treats complete token emission as its boundary, terminates only its owned CLI child, and proceeds immediately to validation. User retest is pending.

Follow-up user observation on 2026-08-26: the OAuth/setup flow still became stuck
after the capture change. The 2026-08-28 implementation now keeps the CLI-owned
localhost listener alive for up to 20 minutes and prevents cancelled attempts
from publishing late state. This is implemented, not yet behaviorally accepted.

User behavioral result on 2026-08-28: setup-token still did not complete. Safari
reported `WebKitErrorDomain:305` and explicitly said the HTTP localhost callback
was blocked because HTTPS-Only was enabled. This run therefore failed before
Safari delivered the request to Claude CLI's listener; it does not support the
earlier five-minute-timeout hypothesis. The authorization values shown by Safari
were not copied into this repository. The user then selected the explicit Claude
Code Keychain compatibility method, which is confirmed working in the app.

Second user result on 2026-08-28: after disabling Safari's HTTP warning,
Safari reported that the Claude connection completed, but Agent Monitor remained
at **Waiting for Claude verification…**. This proves the callback reached Claude
CLI and moves the remaining failure to the CLI-output/capture boundary. Source
inspection found that capture required either a byte after the detected token or
process EOF; Claude Code 2.1.247 can keep its terminal UI alive with the token as
the final bytes. Capture now drains immediately pending PTY output and accepts a
valid trailing token after a 500 ms quiet period. User retest is pending.

Diagnosis update on 2026-08-28: the installed Claude CLI is 2.1.247. Its
`setup-token` help exposes no device-code, callback-forwarding, or noninteractive
option. Before this repair, the app applied one 300-second wall deadline to the
CLI child; that child owns the localhost callback listener, and the timeout path
terminated it. That five-minute deadline has now been replaced with a 20-minute
authorization deadline. The user's browser reaching localhost proves the authorization redirect was
issued, but not that the CLI received or exchanged it. A slow email-verification
flow outliving the app deadline is therefore the first source-supported
hypothesis, not a confirmed cause. Listener/process liveness at failure has not
yet been observed, so listener bind failure, browser/device mismatch, an upstream
CLI regression, and a post-token state transition failure remain possible until
the user retest. Follow the
[callback reliability plan](../superpowers/plans/2026-08-28-claude-setup-token-callback-reliability.md)
to distinguish them without recording the callback URL or raw CLI output.

## Validation

Final user capability result on 2026-08-29: running
`claude setup-token` directly completed authorization,
created a one-year token, printed it once, and exited 0. The token value was
redacted and is not recorded here.

This rules out browser callback and PTY token emission as the final failure.
Claude Code's installed setup-token semantics, the endpoint's rejection, and
matching public Anthropic issue reports establish that the inference credential
does not carry the `user:profile` scope required by `GET /api/oauth/usage`. A
successful setup-token flow therefore cannot validate as an authoritative quota source.
The setup-token route is superseded rather than awaiting another callback
retest. The integrated replacement is the
[Claude Keychain, Passive Usage, and Single-Binary Bridge plan](../superpowers/plans/2026-08-29-claude-keychain-statusline-single-binary.md).

## Relaunch

Unverified. Confirm a scheduled authoritative read succeeds after quitting and relaunching the same signed app.

## Locked-Mac Read

Unverified. Confirm the device-bound after-first-unlock item remains readable after lock and that the app does not prevent system sleep.

## Revocation/401

Implemented replacement: setup-token, app-owned credential routing, and method
selection are removed. Startup migration deletes only the obsolete app-owned
item. One Connect action validates Claude Code's Keychain credential and enrolls
safe passive capture; automatic reads remain non-prompting. Behavioral evidence
is pending.

## Cleanup

Implemented replacement: Disconnect clears enrollment and publishes the local
disconnected state immediately, stops the monitor, removes normalized cache and
exact managed passive-capture artifacts, then retries obsolete app-owned item
cleanup without blocking the UI. Claude Code's item is never deleted. Behavioral
evidence is pending.

User observation on 2026-08-26: the shared Disconnect control appeared inert because its first click only attempted to present a confirmation dialog. The repository's interaction contract defines Disconnect as immediate, so the shared control now invokes the supplied disconnect action directly. User retest is pending.

Follow-up user observation on 2026-08-26: Disconnect still did not work after the
control change. The 2026-08-29 replacement removes the failing credential-router
dependency and makes local state transition first; user retest is pending.

## Prompt Observation

Unverified. Connect may prompt for Claude Code's credential after its disclosure.
Automatic reads use a non-interactive authentication context and never prompt.

## Decision

Do not release the setup-token source gate. The setup-token route and its
app-owned credential state are retired. Keep a fresh status-line snapshot as the zero-secret
fast path, make the explicitly authorized Claude Code Keychain credential the
authoritative OAuth source, and retain `/usage` as manual recovery. The
borrowed-Keychain method is confirmed working. The integrated Disconnect
replacement is implemented and awaits user acceptance.
