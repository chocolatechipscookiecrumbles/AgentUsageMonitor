# Next Release Setup and Provider Reliability Delivery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement the linked plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first post-0.0.1 release with a dismissible first-run tour, explicit independent enrollment for Codex and Claude, a dependable Claude authorization path, and a diagnosed/fixed Codex Token Monitor regression.

**Architecture:** This is a release program composed of three independently reviewable changes. Provider enrollment and onboarding establish the consent/presentation foundation; Claude authorization plugs into that foundation without owning it; Codex local-activity recovery remains a separate data-path diagnosis so an authentication change cannot mask a transcript-reader defect.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation, Security/Keychain, provider-owned CLIs, XCTest, signed macOS `.app` acceptance. No new package dependency.

## Global Constraints

- Both providers begin app-locally unenrolled in this release unless a connection was explicitly established by the new enrollment store. Existing 0.0.1 auto-detection is not treated as consent.
- Onboarding acknowledgement and provider enrollment are separate persisted facts. Completing or dismissing the tour never connects Codex or Claude.
- Codex and Claude enrollment, connection, refresh, failure, disconnect, and cleanup are independent. An action for one provider cannot read, mutate, sign in, sign out, or clear the other.
- Before enrollment, a provider tab shows its header, one provider-specific Connect card, and the global footer only. It shows no quota, cached quota, Token Monitor, status-line result, notification strip, or recovery furniture.
- Quota and Token Monitor keep separate owners and state models. Enrollment is the shared policy gate that permits either owner to start; a failed quota login does not turn a valid local-activity result into an authentication failure.
- Background launch, wake, scheduled refresh, activation, file discovery, and menu opening never trigger a provider login, Keychain prompt, or enrollment transition.
- No home-grown Anthropic PKCE flow ships under another application's OAuth client. Claude authorization must be delegated to a provider-owned CLI flow or use an Anthropic-supported product-owned registration.
- Preserve the privacy boundary: never store or export prompts, responses, raw provider payloads, record paths, session identifiers, OAuth tokens in logs, or Claude Code credentials in app-owned plaintext storage.
- Final acceptance uses the signed `.app`; raw SwiftPM execution is insufficient for onboarding windows, Terminal automation, Keychain prompts, or menu interaction.

## Product Decisions

1. **The tour is educational, not a setup wizard.** It has three short pages, may be closed or skipped at any point, and leaves both providers disconnected.
2. **The first provider action is one Connect button.** After the click, an already authenticated external CLI may be adopted because consent is now explicit; if external sign-in is needed, the provider-specific controller exposes the supported recovery route.
3. **Enrollment gates local reads.** This supersedes the original automatic-read decision in `docs/adr/0001-read-local-token-activity-automatically.md`. A provider's Token Monitor may start after the user selects Connect even if live quota authentication later fails, because enrollment and account connection remain separate facts.
4. **0.0.1 upgrades see the tour and reconnect once.** The released build did not persist explicit provider enrollment, so inferred CLI availability cannot be migrated as consent. Existing provider CLI sessions are not logged out or changed.
5. **“Proper Claude OAuth” means a provider-owned authorization flow.** The public Anthropic documentation and installed Claude Code 2.1.220 expose `claude auth login --claudeai`, `claude auth status --json`, and `claude setup-token`. The dedicated Claude plan requires an end-to-end gate before enabling setup-token capture and never presents an unverified internal endpoint as a public API contract.

## Workstreams

### Workstream A — First launch and provider enrollment

Execute [First Launch and Provider Enrollment](2026-07-31-first-launch-and-provider-enrollment.md).

Deliverable: every installation sees one dismissible tour for this onboarding version, both tabs begin with a single explicit Connect choice, and no provider owner starts before enrollment.

### Workstream B — Claude delegated OAuth and coherent setup

Execute [Claude Delegated OAuth and Setup](2026-07-31-claude-delegated-oauth-and-setup.md) after Workstream A defines the enrollment interfaces.

Deliverable: Claude's explicit Connect action uses a verified provider-owned flow, stores no secret outside Keychain, never prompts in the background, and produces one coherent connection/usage/plan state or one specific recovery state.

### Workstream C — Codex Token Monitor recovery

Execute [Codex Local Activity Recovery Diagnosis](2026-07-31-codex-local-activity-recovery-diagnosis.md). Its diagnostic phase can run before Workstream A, but its production wiring must rebase on the enrollment gate before integration.

Deliverable: the 0.0.1 local-usage failure has an evidence-backed cause, the smallest deterministic regression, and a signed-app proof that current local Codex activity appears or reports a specific unavailable reason.

## Release Sequence

- [ ] **Gate 1:** Run the Codex sanitized diagnostic and the Claude setup-token/auth capability spike. Do not change production behavior until each result is recorded.
- [ ] **Gate 2:** Implement provider enrollment persistence, lifecycle gating, and connect-only menu projection.
- [ ] **Gate 3:** Add the onboarding window and supplied image assets; complete keyboard, VoiceOver, Light/Dark, reduced-motion, close/Skip, and relaunch acceptance.
- [ ] **Gate 4:** Integrate the accepted Claude path and remove or quarantine superseded credential paths.
- [ ] **Gate 5:** Integrate the reproduced Codex fix and its narrow regression test.
- [ ] **Gate 6:** Update `UsageProbe/README.md`, `docs/development/operating-notes.md`, product follow-ups, the planning board, the local-activity ADR, release notes, and the active implementation plans with actual evidence and limitations.
- [ ] **Gate 7:** Run `xcodebuild`, the narrow regressions, the full existing test suite, `CodexUsageMonitor/Scripts/build-app.sh`, `CodexUsageMonitor/Scripts/verify-signed-app-resources.sh`, and `git diff --check` with status 0.
- [ ] **Gate 8:** Exercise the signed-app matrix: fresh/upgrade launch, tour completion/close/Skip, both CLIs signed in/one/neither/missing, independent provider connection order, denial/cancel/retry/relaunch, Codex local activity, Claude Keychain behavior, Light/Dark, keyboard, VoiceOver, and repeated provider switching.

## Release Stop Conditions

- Claude setup-token or the selected credential cannot be validated without exposing the secret.
- A background trigger can display a Keychain or login prompt.
- Either provider can become enrolled merely because its CLI is already authenticated.
- Disconnecting or connecting one provider mutates the other.
- The Codex diagnostic still collapses the released failure into a generic unreadable state without identifying the failed stage.
- Onboarding can disappear without recording acknowledgement, recur every launch after dismissal, or mark a provider connected.
- The supplied onboarding images lack redistribution rights or accessible descriptions.

## Handoff

The implementation order is A foundation, then B and C integration, then the combined signed-app matrix. Do not fold the Codex parser diagnosis into Claude setup or use onboarding copy to hide an unresolved provider failure.
