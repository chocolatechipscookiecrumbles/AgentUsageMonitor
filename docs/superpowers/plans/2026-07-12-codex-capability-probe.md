# Codex Capability Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a read-only Python command-line probe that reports whether the installed Codex can expose authentication, account rate limits, account token usage, and local analytics without starting a model turn.

**Architecture:** A dependency-free Python package contains a reusable `codex_probe` library and a thin module CLI. The core launches Codex through an injected process boundary, speaks newline-delimited app-server JSON, normalizes only documented schema fields, redacts raw output, and emits a versioned JSON report. Fixture-based tests cover protocol parsing and capability classification; the live run is a separate explicit verification step. Python was selected for this disposable research harness after the installed SwiftPM failed to launch because of a toolchain mismatch; the production macOS application remains Swift.

**Tech Stack:** Python 3 standard library, `unittest`, dataclasses, pathlib, subprocess, Codex CLI app-server protocol v2.

## Global Constraints

- Codex only; Claude and GitHub are out of scope.
- Read-only operations only: version, login status, schema discovery, `account/rateLimits/read`, `account/usage/read`, and local file metadata.
- Never read, print, copy, or persist `~/.codex/auth.json` contents.
- Never invoke `codex exec`, send a prompt, consume reset credits, log out, or mutate Codex state.
- Raw provider responses remain in memory and are not written to fixtures or reports.
- Experimental app-server capabilities must be labeled `experimental`, never `supported`.
- Missing fields remain absent; do not infer quota values or reset timestamps.
- The complete app-server lifecycle is `initialize` → `initialized` notification → `account/read` → `account/rateLimits/read` → `account/usage/read`; do not treat a partial handshake as a production integration.
- A single provider response is insufficient evidence for a quota reset. Preserve the last-known-good snapshot until an anomalous change is confirmed.

## Phase 0 findings — 12 July 2026

**Status: complete.** The implemented Python probe has been live-verified with the installed Codex CLI. The task checklists below are the original development record; the user later directed that subsequent work use compilation and live read-only verification rather than generated test cases.

### Capability result

The installed Codex CLI (`0.144.1`) is authenticated with ChatGPT and can return account rate limits and token-usage summaries through the experimental app-server protocol without a model turn. The CLI itself is therefore a viable connection method for a personal prototype.

### Reliability result

The quota values are not reliable enough to display unvalidated. Repeated reads returned two materially different snapshots for the same Plus account while plan type, credit balance, and token-usage summary remained stable:

| Response class | Five-hour used | Weekly used | Five-hour reset behavior |
|---|---:|---:|---|
| Plausible/account state | 48–91% | 52–58% | Stable established reset timestamp |
| Transient/empty state | 1% | 3% | Approximately the request time plus five hours |

The same alternating response was reproduced by a direct OAuth call to the OpenAI `wham/usage` endpoint using the existing Codex login in memory. This rules out the CLI client as the sole cause. The available evidence indicates an upstream quota-cache or usage-service inconsistency; it does not establish the precise backend cause.

### Integration decision

- Keep CLI app-server as the primary personal-prototype connection method because Codex owns the login, token storage, and refresh.
- Treat direct OAuth (`wham/usage`) as an experimental comparison/fallback only. It requires reading the Codex credential file and returned the same inconsistent snapshots.
- Treat a web dashboard as an optional experimental cross-check, implemented only through an app-owned visible `WKWebView`; never depend on Safari automation, screenshots, or imported browser cookies.
- Do not drive notifications, reset reminders, or provider recommendations from a single read.

### Required acceptance policy

Accept a new quota snapshot only when all applicable conditions hold:

1. The account identity and `limitId` match the selected Codex account and main `codex` lane.
2. The reported window duration matches the expected five-hour or weekly lane.
3. A large drop in used percentage is accompanied by a plausible reset-timestamp transition.
4. An anomalous low snapshot is confirmed by a second independent read after a short delay.
5. Otherwise retain and label the last-known-good value as cached/pending confirmation.

---

### Task 1: Package and report model

**Files:**
- Create: `UsageProbe/codex_probe/models.py`
- Create: `UsageProbe/codex_probe/__init__.py`
- Test: `UsageProbe/tests/test_models.py`

**Interfaces:**
- Produces: `ProbeReport`, `CapabilityResult`, `CapabilityStatus`, `RateLimitSnapshot`, and deterministic `ProbeReport.to_dict()`.

- [ ] Write a failing `unittest` test that encodes a minimal report and expects `schemaVersion`, ISO-8601 timestamps, capability status, and no raw provider payload.
- [ ] Run `python3 -m unittest tests.test_models -v` and confirm failure because the model module/types do not exist.
- [ ] Add the minimal dataclass models required by the test.
- [ ] Re-run the focused test and confirm it passes.

### Task 2: App-server response parser

**Files:**
- Create: `UsageProbe/codex_probe/parser.py`
- Test: `UsageProbe/tests/test_parser.py`
- Create: `UsageProbe/Fixtures/Codex/rate-limits-response.jsonl`
- Create: `UsageProbe/Fixtures/Codex/usage-response.jsonl`

**Interfaces:**
- Consumes: newline-delimited JSON responses keyed by request ID.
- Produces: `AppServerParser.rateLimits(from:requestID:)` and `AppServerParser.tokenUsage(from:requestID:)`.

- [ ] Write failing tests for primary/secondary windows, credits, missing optional fields, token summary, interleaved notifications, and server errors.
- [ ] Run `python3 -m unittest tests.test_parser -v` and confirm failures because the parser is missing.
- [ ] Add sanitized synthetic fixtures and the smallest parser that maps only normalized fields.
- [ ] Re-run the focused tests and confirm they pass.

### Task 3: Safe command and app-server client

**Files:**
- Create: `UsageProbe/codex_probe/process.py`
- Create: `UsageProbe/codex_probe/app_server.py`
- Test: `UsageProbe/tests/test_app_server.py`

**Interfaces:**
- Produces: `CommandRunning.run(executable:arguments:stdin:timeout:)`, `AppServerClient.collect(executable:)`, and typed command results.
- Consumes: only the allowlisted Codex arguments defined in Global Constraints.

- [ ] Write failing tests with a recording runner that assert the complete `initialize` → `initialized` → account-read → rate-limit-read → usage-read sequence and reject non-allowlisted operations.
- [ ] Run `python3 -m unittest tests.test_app_server -v` and confirm failure because the client is missing.
- [ ] Implement process execution with stdin piping, concurrent stdout/stderr reads, timeout termination, and the three-request JSONL protocol.
- [ ] Re-run focused tests and confirm they pass.

### Task 4: Capability classification and local metadata

**Files:**
- Create: `UsageProbe/codex_probe/probe.py`
- Test: `UsageProbe/tests/test_probe.py`

**Interfaces:**
- Produces: `CodexProbe.run(codexPath:codexHome:) -> ProbeReport`.
- Consumes: CLI version/login output, app-server normalized results, and file existence/size/modification dates for non-secret Codex state.

- [ ] Write failing tests for missing CLI, logged-out CLI, app-server success, app-server protocol absence, command failure, and secret-file exclusion.
- [ ] Run `python3 -m unittest tests.test_probe -v` and confirm failure because orchestration is missing.
- [ ] Implement capability statuses `experimental`, `local-only`, `unavailable`, and `error`, with diagnostic messages that contain no tokens or raw payloads.
- [ ] Re-run focused tests and confirm they pass.

### Task 5: Executable, documentation, and live finding

**Files:**
- Create: `UsageProbe/codex_probe/cli.py`
- Create: `UsageProbe/codex_probe/__main__.py`
- Create: `UsageProbe/README.md`
- Create: `UsageProbe/Findings/codex.md`
- Create: `UsageProbe/Outputs/.gitkeep`
- Test: `UsageProbe/tests/test_cli.py`

**Interfaces:**
- Produces: `python3 -m codex_probe [--codex PATH] [--codex-home PATH]` JSON on stdout and actionable errors on stderr.

- [ ] Write a failing CLI argument-parser test for defaults, overrides, unknown flags, and help.
- [ ] Run `python3 -m unittest tests.test_cli -v` and confirm failure because the CLI parser is missing.
- [ ] Implement the thin executable and usage documentation.
- [ ] Run the full `python3 -m unittest discover -s tests -v` suite and confirm all tests pass without warnings.
- [ ] Run the live probe with permission to access Codex-owned runtime state, save only normalized JSON to `UsageProbe/Outputs/codex-probe.json`, and record the observed capability classification in `UsageProbe/Findings/codex.md`.
- [ ] Re-run `python3 -m unittest discover -s tests -v` after the live finding and confirm the suite remains green.

### Task 6: Quota snapshot validation

**Execution note:** At the user's request, this task is being verified with live read-only Codex responses and Python compilation rather than automated test cases. Before a production release, restore the listed automated coverage.

**Files:**
- Modify: `UsageProbe/codex_probe/models.py`
- Modify: `UsageProbe/codex_probe/parser.py`
- Modify: `UsageProbe/codex_probe/app_server.py`
- Create: `UsageProbe/codex_probe/validation.py`
- Test: `UsageProbe/tests/test_app_server.py`
- Test: `UsageProbe/tests/test_validation.py`

**Interfaces:**
- Consumes: an account identity, `limitId`, normalized rate-limit windows, and the previous accepted snapshot.
- Produces: a `QuotaDecision` of `accepted`, `pendingConfirmation`, or `rejected`, with a non-sensitive reason.

- [ ] Write failing tests for a stable snapshot, a confirmed reset, a transient 1%/3% snapshot, an account mismatch, a non-`codex` limit ID, and a missing reset timestamp.
- [ ] Run `python3 -m unittest tests.test_validation -v` and confirm failure because quota validation is missing.
- [x] Extend the protocol client to send the full official initialization sequence, request `account/read`, retain `limitId`/a one-way account identity, and parse `rateLimitsByLimitId` without persisting raw responses.
- [x] Implement the minimal validation policy from the Phase 0 findings, including a bounded confirmation read for anomalous values.
- [x] Parse available earned reset-credit expiry timestamps and show them in the compact quota summary when the provider supplies credit details.
- [ ] Run `python3 -m unittest discover -s tests -v` and confirm all tests pass.
- [x] Run a live repeated-sampling study and add sanitized output plus observed acceptance decisions to `UsageProbe/Findings/codex.md`.
