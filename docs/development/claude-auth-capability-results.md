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

## Prompt Observation

Unverified. Setup-token reads should not prompt; borrowed Claude Code access may prompt only after the explicit compatibility action. Automatic reads use a non-interactive authentication context.

## Decision

The source gate is `true` on this feature branch so the user can run the matrix. This is not release approval. Keep the work in verification until capture, validation, relaunch, locked-Mac behavior, cleanup, prompt, and signed UI/menu observations pass.
