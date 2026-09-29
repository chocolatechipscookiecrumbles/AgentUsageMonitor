# Claude Notification Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task.

**Goal:** Let fresh passive and explicit `/usage` readings drive Claude quota alerts without requiring Keychain access.

**Architecture:** Keep `ClaudeUsageCollector`, `QuotaViewModel`, and `QuotaNotifier` as the existing owners. Add one eligibility rule at the notification call site, parse reset timestamps in the existing CLI parser, and pass both Claude refresh flags to the existing header presentation.

**Constraints:** No new scheduler, notifier, persistence store, timer-driven menu update, automatic `/usage`, or source-merging of old reset times.

## Tasks

- [x] Add deterministic regressions proving fresh passive readings are eligible, stale/cached/future-dated readings are not, and source changes retain existing notification deduplication.
- [x] Parse the observed Claude `/usage` reset format and ISO timestamps using an injected reference date and timezone; retain percentages when reset parsing fails.
- [x] Require a future reset independently for each alert window.
- [x] Show `Refreshing…` for collector or CLI work and distinguish Captured, Confirmed, and Cached header states.
- [x] Run focused tests, the macOS scheme build, and signed-app presentation acceptance. Notification delivery is covered deterministically without adding synthetic account history.

## Acceptance

- Fresh passive capture can produce one enabled threshold alert while OAuth is unavailable.
- Repeated refreshes, source transitions, and relaunch do not repeat the same window/threshold alert.
- `/usage` preserves both observed reset times; failure retains the previous reading.
- Missing or expired reset times never alert.

## Verification — 2026-09-23

The integrated focused suite passed 214 tests with zero failures. The macOS
scheme and signed app build both exited 0. In the signed app, ordinary Refresh
completed without a Keychain prompt, and explicit `/usage` showed `Reading…`,
then published both reset times as a Claude Code CLI reading. The live test also
exposed and fixed a financial-retention boundary: a quota-only CLI snapshot now
keeps the prior independently timestamped financial observation.
