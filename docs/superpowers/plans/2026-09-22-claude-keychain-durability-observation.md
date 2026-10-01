# Claude Keychain Durability Observation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `diagnosing-bugs` and `swift-security-expert`.

**Goal:** Determine whether recurring silent-read failures come from lookup drift, token rejection, or provider-owned Keychain access-rule changes.

**Architecture:** Keep one signed app identity and compare sanitized snapshots before Reconnect, immediately after an explicitly observed choice, and at the first later failure. Store evidence only in the existing diagnosis record; never modify the provider credential or its access rules.

**Constraints:** No credential bytes, ACL edits, search-list edits, direct renewal, production polling, forced sleep/wake, or inferred Always Allow choice.

## Tasks

- [x] Capture the default-Keychain result, lock state, typed credential error, credential cdat/mdat, app designated requirement, and relevant securityd event timestamps with bounded noninteractive commands.
- [x] Record the user-observed Reconnect choice, then immediately repeat the silent read and metadata snapshot.
- [ ] Observe normal operation for up to 24 hours, including only naturally occurring credential update, relaunch, and sleep/wake events.
- [ ] At the first failure, preserve the failed state, capture the same fields once, and classify it using the plan’s decision rules.
- [ ] Record unobserved events as untested; never claim permanent grant durability from a successful interval.

## User observation — 2026-09-30

During 0.1.0 acceptance the user reported, without timestamps or captured fields, that macOS occasionally shows the Keychain access prompt again, and that silent access sometimes fails until Claude is reconnected through Settings. This matches the failure the tasks above are designed to classify; it is not yet classified. The next occurrence should be captured once per Task 2 before reconnecting.

## Acceptance

The evidence separates access-rule change, lookup mismatch, and OAuth rejection, or states precisely which required event did not occur.

## Current boundary — 2026-09-23

Security logs recorded **Always Allow** for the stable signed checkout identity,
and silent OAuth still succeeded 2h 36m 45s later. No natural Claude credential
update occurred during that interval. Credential-update, sleep/wake, and later
failure behavior therefore remain untested; durability is still unresolved.
