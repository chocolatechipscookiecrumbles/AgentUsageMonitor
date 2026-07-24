# Claude Usage Monitor — Manual Verification Guide

Runnable commands to verify each layer of the Claude usage monitor against a **real machine and account**. This is deployment/smoke verification, not the unit suite.

All paths are relative to the repo root: `<USER_HOME>/Desktop/agent usage`.

**Source hierarchy under test:**

| Tier | Source | Status |
|---|---|---|
| 1 | OAuth — **(b) Claude Code credentials** [working] / (a) `setup-token` [shelved, unverified] | (b) live; (a) unproven |
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
**Expected:** `Executed 229 tests, with 0 failures`

```bash
cd CodexUsageMonitor && swift test --filter Claude
```
**Expected:** `Executed 193 tests, with 0 failures`

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

### 3b. Method (a): browser sign-in via `setup-token` — ⚠️ SHELVED / UNVERIFIED

> **This method is not proven to work.** A real `setup-token` was rejected (`401`) by `/api/oauth/usage`, but the control endpoint also rejected it, so the test was inconclusive — see the [spike findings addendum](superpowers/plans/2026-07-21-claude-oauth-web-login-spike-findings.md#addendum--claude-setup-token-shelved-as-unresolved-2026-07-22). Use **method (b)** for real verification. The steps below are retained for the decisive re-test only; run `scripts/diagnose-setup-token.sh` and check the `/v1/models` + `x-api-key` row first.

The intended path — no Keychain prompt, no `/v1/oauth/token` call from our app.

```bash
claude setup-token
```
**Expected:** a browser opens for Anthropic's own consent screen; on approval the terminal prints a token beginning `sk-ant-oat01-…`.

**If you get `zsh: command not found: claude`** the Claude Code CLI isn't installed. Install it with the **official installer**, which detects the machine's real architecture:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```
**Expected:** `✔ Claude Code successfully installed!` · `Location: ~/.local/bin/claude`

> ⚠️ **Do not use `brew install claude`** — that cask is the Claude **desktop GUI app**, a different product. If `/Applications/Claude.app` exists it fails with `Error: It seems there is already an App at '/Applications/Claude.app'`.
>
> ⚠️ **`npm install -g @anthropic-ai/claude-code` fails on an Apple Silicon Mac running x64 Node under Rosetta.** npm resolves the `darwin-x64` binary, which needs AVX that Rosetta doesn't emulate, and `claude --version` then reports `native binary not installed`. Check with `file $(which node)` and `uname -m`; if they disagree (`x86_64` vs `arm64`), use the installer script above. Remove any broken shim first — `npm uninstall -g @anthropic-ai/claude-code` — because a non-working `/usr/local/bin/claude` shadows a good install in the locator's search order.

Alternatively, obtain a token on a machine that has the CLI and use the **environment-variable path below**, which works without the CLI present.

**If the browser refuses the callback** (Safari HTTPS-Only — see Troubleshooting), the flow still worked; only delivery failed. While `claude setup-token` is *still running*, hand it the callback manually — copy the whole failed URL from the browser and:

```bash
# confirm the listener is still up (port is in the failed URL)
lsof -nP -iTCP:57409 -sTCP:LISTEN

# deliver the callback; HTTP 302 means accepted
curl -sS "http://localhost:57409/callback?code=PASTE_CODE&state=PASTE_STATE" -w "\n[HTTP %{http_code}]\n"
```
The token then prints in the terminal where `setup-token` is running. The authorization code is single-use and short-lived, so it is spent the moment this succeeds.

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
**Expected with a valid token:** `"tier1Method" : "browser"` — and **no Keychain dialog**, because the environment token is resolved before our Keychain item is ever consulted.

`CLAUDE_CODE_OAUTH_TOKEN` is honoured at **read** time, not only during sign-in (`ClaudeSelfIssuedCredentialStore` resolves env → own Keychain item). This is the only way to exercise method (a) on a machine without the `claude` CLI.

### 3b-2. Prompt policy — background refreshes must never raise a dialog

The safety property behind method (b): only an explicit user action may prompt.
`ClaudeRefreshReason` maps `.userInitiated` → `.userInitiatedOnly`; `.scheduled`,
`.menuOpened` and `.appLaunch` all map to `.never`, which sets
`kSecUseAuthenticationUI = kSecUseAuthenticationUIFail` on the Keychain query so
macOS fails the read instead of showing a dialog. A denied read degrades to the
next tier rather than erroring.

```bash
cd CodexUsageMonitor && swift test --filter PromptPolicy
```
**Expected:** `Executed 10 tests, with 0 failures` — covering the query flags, the
`errSecInteractionNotAllowed` → `.accessDenied` mapping, and that each automatic
refresh reason reaches the credential read with `.never`.

> ⚠️ **This cannot be verified empirically once you have clicked "Always Allow".** With a
> standing ACL grant the read succeeds without a dialog either way, so the prompt path is
> unreachable on this machine. The unit tests asserting the constructed query are the
> available verification. To exercise it for real you would need to revoke the grant in
> Keychain Access (delete the app's entry in the item's Access Control tab).

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
# A bogus env token is resolved as the tier-1 credential, then rejected by the
# server — so tier 1 fails and the coordinator must fall through.
cd CodexUsageMonitor && CLAUDE_CODE_OAUTH_TOKEN='sk-ant-oat01-invalid' \
  .build/debug/CodexUsageMonitor --claude-live-read-once \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print('tier1Method:', r.get('tier1Method')); print('coordinator ->', r['coordinatorResult']['delivery'], '/', r['coordinatorResult']['source']); [print(f\"  tier {l['tier']} {'OK' if l['available'] else '--'}  {l['detail'][:75]}\") for l in r['layers']]"
```
**Verified output:**
```
tier1Method: None
coordinator -> passiveSnapshot / statusLine
  tier 1 --  unavailable: unauthorized
  tier 2 --  deferred — not implemented in the coordinator
  tier 3 OK  5h 5.0% · 7d — · captured 2026-07-20 15:42:57 +0000
  tier 4 OK  source oauth · saved 2026-07-22 04:31:23 +0000
```
Tier 1 is `unavailable: unauthorized`, `tier1Method` is null (nothing served it), and delivery degrades to `passiveSnapshot` — **never** a zeroed or invented tier-1 result.

> Note: a bogus token makes the *credential load* succeed and the *server call* fail. The composite's method-to-method degrade only fires when `loadCredential` itself throws, so this scenario drops to tier 3 rather than to method (b). Auto-degrading a **revoked** self-issued token back to Claude Code credentials requires `invalidateSelfIssued()`, which nothing calls yet — see Known gaps.

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
| `zsh: command not found: claude` | Claude Code CLI not installed | Install it, or use the `CLAUDE_CODE_OAUTH_TOKEN` path (§3b) which needs no CLI |
| `setup-token` browser shows *"Navigation failed because the request was for an HTTP URL with HTTPS-Only enabled"* (WebKitErrorDomain:305) | Safari's **HTTPS-Only mode** blocks the `http://localhost:PORT/callback` loopback that `setup-token` listens on. The OAuth flow *succeeded* — the code is in the URL — the browser just won't deliver it | Deliver the callback yourself (see below), or turn off Safari → Settings → Privacy → **HTTPS-Only mode**, or make a non-Safari browser the default before running `setup-token` |
| `command not found: timeout` | macOS has no GNU `timeout` | Drop it, or `brew install coreutils` and use `gtimeout` |
| Tier 3 hours/days stale | Expected — it's a passive capture, only written after a real Claude Code turn | Use tier 1 for current numbers |

---

## 10. Known gaps (do not report as bugs)

- **Tier 2 (CLI `/usage`) is not implemented** — deferred to its own plan.
- **Claude credential sign-in is now reachable in the app** — Settings ▸ Agents ▸ Claude Code and the menu-bar popover's Claude tab both offer **Use Claude Code credentials…** (tier-1 method (b)). Browser/`setup-token` sign-in (method (a)) stays shelved and is deliberately not offered in the UI, so only method (b) is exercisable there; the probe and `CLAUDE_CODE_OAUTH_TOKEN` still exercise method (a).
- **`--claude-live-read-once` currently hardcodes `selectedMethod: .browser`**, since there's no persisted setting yet — so it always prefers a self-issued token and degrades to Claude Code credentials.
- **A revoked self-issued token does not auto-degrade to method (b).** `ClaudeCompositeCredentialStore.invalidateSelfIssued()` exists and is tested, but nothing calls it yet — that hook belongs to the not-yet-built Settings wiring. Today a bad tier-1 credential drops to tier 3 instead.
- **`ClaudeStatusLineInstaller`'s production bridge path doesn't resolve** — `ClaudeUsageBridge/` isn't bundled into a signed `.app`.

---

## 11. Extra usage (Anthropic pay-as-you-go credits)

`GET /api/oauth/usage` **does** return credit data, in an `extra_usage` object. Verified live on a Pro account 2026-07-22:

```json
"extraUsage": { "isEnabled": true, "usedCredits": 0, "currencyCode": "USD" }
```

Inspect the live value:
```bash
python3 -c "
import json,os
p=os.path.expanduser('~/Library/Application Support/CodexUsageMonitor/claude-usage-cache.json')
print(json.dumps(json.load(open(p))['snapshot'].get('extraUsage'), indent=2))
"
```

### ⚠️ It is NOT the same concept as Codex credits

| | Codex | Claude |
|---|---|---|
| `creditBalance` | a balance you **hold** | — |
| `availableResetCredits` + expiries | credits available to spend | — |
| `usedCredits` | — | money **already spent** on overage |
| `monthlyLimit` | — | the spend **cap** (absent on this account) |

Claude's figure is **spend against a cap**, not a balance held. Rendering `usedCredits: 0` in a Codex-style "Credit Balance" row would read as *"0 credits left"* when it means *"$0 spent"* — the opposite. The Settings page therefore uses its own **Extra usage** section (`Pay-as-you-go: On`, `Spent this month: $0.00 spent`), and `ClaudeUsageDisplayModel.ExtraUsage` phrases every string as spend, never as remaining. A unit test asserts the word "remaining" never appears.

`monthlyLimit` was **not** returned for this account, so no cap is displayed and none is implied. If it appears on other plans the summary becomes `"$X of $Y spent"` automatically.

### Not surfaced

`scopedWindows` (`session`, `weekly_all`) duplicate the five-hour and weekly figures — `session` tracked 45% against a five-hour 44%, `weekly_all` 28% against a weekly 28%. They add no information and are deliberately not shown.

---

## 12. Menu-bar popover (menu-level manual checks)

These verify the multi-provider popover that replaced the old inline menu (`QuotaMenuView` / `ConnectedQuotaMenuView` / `CodexDisconnectedMenuView`, now removed). Build and launch the app first:

```bash
CODESIGN_IDENTITY=- zsh CodexUsageMonitor/Scripts/build-app.sh
open CodexUsageMonitor/.build/CodexUsageMonitor.app
```

> ⚠️ This branch **waives** visual/keyboard/VoiceOver/Light-Dark acceptance. The steps below are the menu-level script to run against the real app — record them as **unobserved** until a human performs them, never as passed.

**Tabs and persistence (Task 7)**
- The popover opens with **Codex** and **Claude** tabs; **Copilot is absent** (unsupported).
- Switch to **Claude**, close and reopen the popover — it reopens on **Claude** (`AppSettings.selectedMenuProvider` round-trips; covered by `MenuProviderSelectionPersistenceTests`).
- A *supported* provider with no current snapshot keeps its tab selected (Claude stays Claude); only an *unsupported* persisted provider falls back to Codex (`MenuPopoverProviderResolutionTests`).

**Shell, tabs, and header (both tabs)**
- The popover is a **single rounded piece** — no square background or stray artifacts peeking at the four corners.
- The **Codex** / **Claude** tabs are easy to hit: the whole equal-width column (not just the text) switches tabs, and hovering fills the column.
- The header title is just the provider name — **Codex** / **Claude**, not "… Usage Monitor".
- The subtitle is the standard `Updated: <time> · <relative>` with **no seconds** (e.g. `Updated: 3:42 PM · 3 minutes ago`) on both tabs, plus the **Confirmed / Cached / Refreshing / Unavailable** status pill.
- Usage bars and the `% used` numerals are **green below 75%, yellow 75–90%, red above 90%** — the same on both tabs, and the color follows usage regardless of used/remaining wording. (Settings' bars keep their provider tint by design.)

**Codex tab**
- Two window cards (Five Hour, Weekly): `N% used` at right, `Remaining M%` and reset timing in the footer, and a forecast line when one is available.
- The credit-balance card appears only when Codex reports a balance or earned reset credits; the popover balance is rounded to **4 significant figures** (Settings ▸ Agents ▸ Codex shows it in full).
- A **cached** read shows the "Showing Last Confirmed Snapshot" strip above the cards.
- Disconnected: the tab shows a connection card with **Sign in with browser** and **Sign in with Codex CLI…**. Connected-but-no-snapshot shows "Unable to Read Usage" with **no** sign-in buttons — recovery is the footer's **Refresh Now**.
- There is **no** quota-alerts toggle in the popover (it lives in Settings).

**Codex icon**
- On the Codex tab the header tile is filled edge-to-edge by the Codex mark (it carries its own square background); the Claude tile keeps padding around its glyph.

**Claude tab**
- A `Read from: <source>` caption (e.g. `Read from: Claude OAuth`) sits beneath the window card — this is where Claude provenance lives now (the capture time is the header's freshness line).
- Two window cards (Five Hour, Weekly). The weekly card carries the shared-pool caveat; when the five-hour window has not started (live data only), it shows the session note.
- A non-live read shows the staleness strip above the cards.
- **No** credit card and **no** collector line appear (Codex-only furniture is absent here).
- With no reading: an unavailable card offers **Use Claude Code credentials…** only (browser sign-in is shelved). macOS raises the Keychain prompt **only** on that explicit click — never on open.
- An *actively failed* connection shows a recovery card alongside the last result; a *merely-not-connected* passive read does not (passive capture needs no connection).

**Notifications (both tabs)**
- When macOS notification permission is **denied**, a slim strip with "Notifications are disabled in System Settings." + **Open System Notification Settings** appears on both tabs; it is absent otherwise.

**Footer and passivity**
- The bottom action row runs **Refresh Now**, **Notification Settings**, **Preferences…**, and **Quit Codex Usage Monitor**, flush to the edges: **Refresh Now** sits against the divider and **Quit** against the bottom edge, no extra padding. **Refresh Now** keeps the popover open, targets the active tab's provider, and exposes the in-place `Refreshing…` state. The other footer commands dismiss first.
- [ ] With the production signed app, press **Escape** while the popover is open and confirm it dismisses without activating a footer command.
- Opening the popover triggers no refresh, timer, `TimelineView`, or per-second invalidation.

**Unobserved signed-app regression matrix**
- [ ] Manufacture an expired Claude five-hour window beside an active weekly window; confirm the tab and compact menu-bar summary use only the active weekly value.
- [ ] Overlap a launch or scheduled Claude refresh with a manual **Refresh Now** click; confirm only one read runs, the button remains disabled for that read, and the state clears on completion.
- [ ] Run **Refresh Now** for both providers; confirm the popover remains open through completion and updates the header/footer state in place.
- [ ] Manufacture the maximum-height Codex combination: cached warning, both forecasts, credits, disconnected recovery, and denied-notification strip. Confirm every footer action remains visible without scrolling or clipping.
- [ ] Supply more than two reset-credit expiries; confirm exactly two dates and the “+N more in Settings” caption appear, while Settings retains the complete list.
- [ ] Repeat the maximum-height, refresh, tab-switch, and Escape checks in Light and Dark appearance with keyboard focus and VoiceOver. Confirm focus order, activation, announcements, and escape from the popover.
- [ ] Alternate Codex and Claude tabs repeatedly on both the Settings Agents page and popover; record any jumping, delayed click, or stuck selection before attempting a fix.
- [ ] Inspect native-pixel crops of all four popover corners on first open, repeated open, and provider switches; the currently reported artifact remains unresolved.
