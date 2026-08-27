# Claude setup-token capability results

Status: **implemented on feature branch; user behavioral acceptance required**

Date: 2026-08-26

Branch: `feat/claude-setup-token-primary`

This record must never contain an account email, organization, token, response body, raw CLI output, or Keychain item data.

## Environment

- macOS version: not recorded; user acceptance pending
- Claude CLI version: not recorded; user acceptance pending
- signed app build and signing identity: pending

## Capture

Implemented with a cancellable PTY, an 8 KiB in-memory bound, a five-minute timeout, and token-only parsing. Live signed-app capture is unverified.

User observation on 2026-08-26: Claude Code completed email verification and displayed its connected state, but Agent Monitor remained disconnected. Root cause was the PTY capture waiting for CLI EOF after it had already isolated a complete token. The capture now treats complete token emission as its boundary, terminates only its owned CLI child, and proceeds immediately to validation. User retest is pending.

Follow-up user observation on 2026-08-26: the OAuth/setup flow still becomes stuck after the capture change. The earlier correction is therefore not behaviorally accepted; the remaining boundary is unresolved and intentionally deferred for a later focused diagnosis.

## Validation

The candidate is validated against the usage endpoint before it is saved. Live 200/usage-window evidence is unverified.

## Relaunch

Unverified. Confirm a scheduled authoritative read succeeds after quitting and relaunching the same signed app.

## Locked-Mac Read

Unverified. Confirm the device-bound after-first-unlock item remains readable after lock and that the app does not prevent system sleep.

## Revocation/401

Implemented: setup-token rejection deletes only the app-owned item and never invokes delegated refresh or borrowed Keychain access. Behavioral evidence is pending.

## Cleanup

Implemented: Disconnect awaits app-owned item deletion before clearing selection and enrollment; Claude Code's item is never deleted. Behavioral evidence is pending.

User observation on 2026-08-26: the shared Disconnect control appeared inert because its first click only attempted to present a confirmation dialog. The repository's interaction contract defines Disconnect as immediate, so the shared control now invokes the supplied disconnect action directly. User retest is pending.

Follow-up user observation on 2026-08-26: Disconnect still does not work after the control change. The earlier correction is therefore insufficient; the underlying disconnect path remains unresolved and is intentionally deferred.

## Prompt Observation

Unverified. Setup-token reads should not prompt; borrowed Claude Code access may prompt only after the explicit compatibility action. Automatic reads use a non-interactive authentication context.

## Decision

The source gate is `true` on this feature branch so the user can run the matrix. This is not release approval. OAuth/setup completion and Disconnect are known broken behaviors, and the remaining capture, validation, relaunch, locked-Mac behavior, cleanup, prompt, and signed UI/menu observations are unverified.
