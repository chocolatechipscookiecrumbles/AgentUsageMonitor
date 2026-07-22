# Claude Usage Monitor — Manual Verification Guide

Runnable commands to verify each layer of the Claude usage monitor against a **real machine and account**. This is deployment/smoke verification, not the unit suite.

All paths are relative to the repo root: `<USER_HOME>/Desktop/agent usage`.

**Source hierarchy under test:**

| Tier | Source | Status |
|---|---|---|
| 1 | OAuth — method (a) browser `setup-token` **or** (b) Claude Code credentials | (b) live, (a) built |
| 2 | CLI `/usage` PTY probe | not implemented |
| 3 | statusLine passive snapshot | live |
| 4 | cached last-known-good | live |

> ⚠️ **Keychain prompts.** Any command that exercises tier-1 method (b) reads Claude Code's Keychain item and **macOS will show a permission dialog**. The command *blocks* until you answer it. Never run those unattended (e.g. in CI or a background shell) — they will hang. Commands that prompt are marked **[PROMPTS]**.

---

## 0. Build

```bash
cd CodexUsageMonitor && swift build
```

**Expected:**
```
Build complete! (1.65s)
```

---

## 1. Automated suites (fast sanity gate)

Run these first — if they fail, don't bother with the live checks.

```bash
cd CodexUsageMonitor && swift test
```
**Expected:** `Executed 101 tests, with 0 failures`

```bash
cd CodexUsageMonitor && swift test --filter Claude
```
**Expected:** `Executed 93 tests, with 0 failures`

```bash
cd ClaudeUsageBridge && /opt/anaconda3/bin/pytest -q
```
**Expected:** `13 passed in 0.03s`

> Note: the system `python3` (3.14) has no `pytest`. Use the anaconda one above, or `python3 -m pytest` from an env that has it.

---

## 2. The four-layer probe (primary end-to-end check) **[PROMPTS]**

The single command that exercises every tier and reports which one served.

```bash
cd CodexUsageMonitor && .build/debug/CodexUsageMonitor --claude-live-read-once
```

**Expected shape** (values will differ):
```json
{
  "coordinatorResult" : {
    "capturedAt" : "2026-07-21T11:20:47Z",
    "delivery" : "live",
    "fiveHourUsedPercent" : 10,
    "planHint" : "pro",
    "sevenDayUsedPercent" : 14,
    "source" : "oauth",
    "warnings" : []
  },
  "layers" : [
    { "tier" : 1, "name" : "OAuth live fetch",             "available" : true,  "detail" : "5h 10.0% · 7d 14.0% · plan pro · via Claude Code credentials" },
    { "tier" : 2, "name" : "CLI /usage PTY probe",         "available" : false, "detail" : "deferred — not implemented in the coordinator" },
    { "tier" : 3, "name" : "statusLine passive snapshot",  "available" : true,  "detail" : "5h 5.0% · 7d — · captured ..." },
    { "tier" : 4, "name" : "cached last-known-good",       "available" : true,  "detail" : "source oauth · saved ..." }
  ],
  "ranAt" : "...",
  "tier1Method" : "claudeCodeCredentials"
}
```

**What to check:**
- `tier1Method` — `"browser"` if you've signed in with `setup-token`, `"claudeCodeCredentials"` if it degraded to reading Claude Code's item. A degrade must always be visible here.
- `coordinatorResult.delivery` — `live` (tier 1), `passiveSnapshot` (tier 3), or `cached` (tier 4).
- **No token appears anywhere in the output.** If you ever see an `sk-ant-` string here, that's a defect — stop and report it.

**Readable one-liner:**
```bash
cd CodexUsageMonitor && .build/debug/CodexUsageMonitor --claude-live-read-once \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print('tier1 via:', r.get('tier1Method')); print('coordinator ->', r['coordinatorResult']['delivery'], '/', r['coordinatorResult']['source']); [print(f\"  tier {l['tier']} {l['name']:30} {'OK' if l['available'] else '--'}  {l['detail']}\") for l in r['layers']]"
```
**Expected:**
```
tier1 via: claudeCodeCredentials
coordinator -> live / oauth
  tier 1 OAuth live fetch                OK  5h 10.0% · 7d 14.0% · plan pro · via Claude Code credentials
  tier 2 CLI /usage PTY probe            --  deferred — not implemented in the coordinator
  tier 3 statusLine passive snapshot     OK  5h 5.0% · 7d — · captured ...
  tier 4 cached last-known-good          OK  source oauth · saved ...
```

---

## 3. Tier 1 — credential methods

### 3a. Method (b): Claude Code credentials **[PROMPTS]**

Prove the borrowed-credential path works and that the prompt is what gates it.

```bash
security find-generic-password -s "Claude Code-credentials" -w > /dev/null && echo "READ OK"
```
**Expected:** a Keychain dialog, then `READ OK` after you click **Allow**.
If you click **Deny**: `security: SecKeychainSearchCopyNext: User canceled the operation.`

> This is the same dialog the app raises. `security` is a *different binary* from Claude Code, exactly like our app — which is why it prompts too. That's the mechanism, not a bug.

### 3b. Method (a): browser sign-in via `setup-token`

The sanctioned path — no Keychain prompt, no `/v1/oauth/token` call from our app.

```bash
claude setup-token
```
**Expected:** a browser opens for Anthropic's own consent screen; on approval the terminal prints a token beginning `sk-ant-oat01-…`.

> 🔐 **Treat this token like a password.** It grants ~1 year of account access. Don't paste it into chats, logs, or issues.

Verify it works against the usage endpoint (substitute your token):
```bash
curl -sS -w '\nHTTP %{http_code}\n' https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer sk-ant-oat01-REPLACE_ME" \
  -H "anthropic-beta: oauth-2025-04-20"
```
**Expected:** `HTTP 200` and a JSON body containing `five_hour` / `seven_day` objects with `utilization` and `resets_at`.

Feed it to the app without spawning the CLI (the env-var path):
```bash
cd CodexUsageMonitor && CLAUDE_CODE_OAUTH_TOKEN='sk-ant-oat01-REPLACE_ME' \
  .build/debug/CodexUsageMonitor --claude-live-read-once | grep tier1Method
```
**Expected:** `"tier1Method" : "browser"` — and **no Keychain dialog**.

### 3c. Inspect / clear our own Keychain item

Our self-issued item (created by browser sign-in) — reading it **never** prompts, because we own it:
```bash
security find-generic-password -s "AgentUsageMonitor-ClaudeOAuth" 2>&1 | head -5
```
**Expected before sign-in:** `security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.`
**Expected after sign-in:** attribute dump (no dialog).

"Sign out" equivalent:
```bash
security delete-generic-password -s "AgentUsageMonitor-ClaudeOAuth" && echo "signed out"
```

---

## 4. Tier 2 — CLI `/usage` probe

Not implemented; the probe reports it as deferred. There is no command to run. Expected probe line:
```
tier 2 CLI /usage PTY probe  --  deferred — not implemented in the coordinator
```

---

## 5. Tier 3 — statusLine bridge

### 5a. Confirm Claude Code is wired to the bridge

```bash
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude/settings.json'))); print(json.dumps(d.get('statusLine'), indent=2))"
```
**Expected:**
```json
{
  "command": "cd '<USER_HOME>/Desktop/agent usage/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet",
  "type": "command"
}
```

### 5b. Drive the bridge manually

```bash
cd ClaudeUsageBridge && echo '{"rate_limits":{"five_hour":{"used_percentage":12.0,"resets_at":1800000000},"seven_day":{"used_percentage":34.0,"resets_at":1800500000}}}' \
  | python3 -m claude_usage_bridge --output ~/Desktop/snap-test.json
```
**Expected stdout:**
```
Claude usage: 5h 12% · 7d 34%
```
**Expected file:**
```json
{"capturedAt": 1784693479, "fiveHour": {"resetsAt": 1800000000, "usedPercentage": 12.0}, "schemaVersion": 1, "sevenDay": {"resetsAt": 1800500000, "usedPercentage": 34.0}}
```

Quiet mode (what Claude Code actually invokes):
```bash
cd ClaudeUsageBridge && echo '{"rate_limits":{"five_hour":{"used_percentage":1.0,"resets_at":1800000000}}}' \
  | python3 -m claude_usage_bridge --quiet --output ~/Desktop/snap-test.json && echo "(silent = correct)"
```
**Expected:** no stdout, then `(silent = correct)`.

> ⚠️ **`--output` gotcha:** the writer `chmod`s the output's **parent directory** to `0700`, so it must be a directory you own. `--output /tmp/x.json` fails with `PermissionError: [Errno 1] Operation not permitted: '/tmp'`. Use `~/Desktop`, `~/tmp`, or the default path.

### 5c. Inspect the live snapshot the app reads

```bash
cat ~/Library/Application\ Support/CodexUsageMonitor/claude-rate-limits.json
```
**Expected:**
```json
{"capturedAt": 1784562177, "fiveHour": {"resetsAt": 1800000000, "usedPercentage": 5.0}, "schemaVersion": 1}
```

**Freshness check** — tier 3 is *passive*, so it only updates after a real Claude Code turn. Confirm how stale it is:
```bash
python3 -c "import json,os,time; p=os.path.expanduser('~/Library/Application Support/CodexUsageMonitor/claude-rate-limits.json'); d=json.load(open(p)); age=(time.time()-d['capturedAt'])/3600; print(f'captured {age:.1f} h ago')"
```
**Expected:** a number. **If this is many hours old, that is the known staleness limitation** — it's why tier 3 ranks below tier 1 and the (future) tier 2.

---

## 6. Tier 4 — cache

```bash
python3 -m json.tool ~/Library/Application\ Support/CodexUsageMonitor/claude-usage-cache.json
```
**Expected:** a `savedAt` plus a full `snapshot` — note it retains `source: "oauth"` (where the data came from) separately from delivery:
```json
{
    "savedAt": 806296847.134448,
    "snapshot": {
        "source": "oauth",
        "planHint": "pro",
        "fiveHour": { "usedPercent": 10, "resetsAt": 806309399.96 },
        "sevenDay": { "usedPercent": 14, "resetsAt": 806450399.96 },
        "scopedWindows": [ { "identifier": "session", ... }, { "identifier": "weekly_all", ... } ],
        "extraUsage": { "isEnabled": true, "usedCredits": 0, "currencyCode": "USD" },
        "schemaVersion": 1
    }
}
```

**Verify permissions** (owner-only, per the privacy boundary):
```bash
ls -l ~/Library/Application\ Support/CodexUsageMonitor/claude-usage-cache.json
```
**Expected:** `-rw-------` (0600).

**Verify no credential ever lands in the cache** — this must return nothing:
```bash
grep -o 'sk-ant-[a-zA-Z0-9-]*' ~/Library/Application\ Support/CodexUsageMonitor/*.json; echo "exit=$? (1 = clean, no token found)"
```
**Expected:** no output, `exit=1`.

---

## 7. Degrade behavior

Force tier 1 to fail and confirm the coordinator falls through rather than inventing a number.

```bash
# Break tier 1 by pointing at a bogus token (env path short-circuits the CLI)
cd CodexUsageMonitor && CLAUDE_CODE_OAUTH_TOKEN='sk-ant-oat01-invalid' \
  .build/debug/CodexUsageMonitor --claude-live-read-once | head -30
```
**Expected:** tier 1 `"available": false`, and `coordinatorResult.delivery` becomes `passiveSnapshot` (tier 3) or `cached` (tier 4) — **never** a zeroed tier-1 result.

Force everything to fail (temporarily move the local files aside):
```bash
cd ~/Library/Application\ Support/CodexUsageMonitor && mv claude-rate-limits.json claude-rate-limits.json.bak && mv claude-usage-cache.json claude-usage-cache.json.bak
cd "<USER_HOME>/Desktop/agent usage/CodexUsageMonitor" && CLAUDE_CODE_OAUTH_TOKEN='sk-ant-oat01-invalid' .build/debug/CodexUsageMonitor --claude-live-read-once | tail -20
```
**Expected:** a warning `"No Claude usage source is currently available."` and **no fabricated percentages**.

**Restore:**
```bash
cd ~/Library/Application\ Support/CodexUsageMonitor && mv claude-rate-limits.json.bak claude-rate-limits.json && mv claude-usage-cache.json.bak claude-usage-cache.json
```

---

## 8. Codex comparison (control)

Confirms the Codex path still works and — importantly — **never prompts**, because it delegates to the `codex` CLI.

```bash
cd CodexUsageMonitor && .build/debug/CodexUsageMonitor --live-read-once
```
**Expected:** a JSON usage presentation, **no Keychain dialog**. Codex keeps credentials in a plain file:
```bash
ls -l ~/.codex/auth.json
```
**Expected:** `-rw-------` — a `0600` file, no Keychain, hence no ACL prompt.

---

## 9. Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| Command hangs with no output | Keychain dialog is open behind another window, waiting | Answer the dialog. Never run **[PROMPTS]** commands unattended. |
| Prompt reappears every run | You clicked **Allow** (once), not **Always Allow**; and debug binaries aren't stably signed so ACL grants don't persist across rebuilds | Use browser sign-in (§3b) to avoid it entirely |
| `HTTP 429 rate_limit_error` on `/v1/oauth/token` | IP-level throttle on the **token exchange** endpoint, tripped by rapid retries | Wait 15–30 min making **zero** requests to it — probing resets the window. Note the app itself never calls this endpoint; only manual PKCE experiments do. |
| `tier1Method` is `claudeCodeCredentials` when you expected `browser` | No self-issued token stored, so it degraded | Run `claude setup-token`, or check §3c that the item exists |
| `PermissionError ... '/tmp'` from the bridge | `--output` parent dir isn't user-owned (bridge chmods it `0700`) | Use a directory you own |
| `No module named pytest` | System python 3.14 lacks it | Use `/opt/anaconda3/bin/pytest` |
| Tier 3 hours/days stale | Expected — it's a passive capture, only written after a real Claude Code turn | Use tier 1 for current numbers |

---

## 10. Known gaps (do not report as bugs)

- **Tier 2 (CLI `/usage`) is not implemented** — deferred to its own plan.
- **The sign-in UI is not reachable in the app yet.** `ClaudeConnectionController` / `ClaudeSignInView` are built and tested but not wired into `AgentsSettingsView`; that's the [wiring plan](superpowers/plans/2026-07-21-claude-usage-provider-wiring.md). Until then, method selection is only exercisable via the probe and `CLAUDE_CODE_OAUTH_TOKEN`.
- **`--claude-live-read-once` currently hardcodes `selectedMethod: .browser`**, since there's no persisted setting yet — so it always prefers a self-issued token and degrades to Claude Code credentials.
- **`ClaudeStatusLineInstaller`'s production bridge path doesn't resolve** — `ClaudeUsageBridge/` isn't bundled into a signed `.app`.
