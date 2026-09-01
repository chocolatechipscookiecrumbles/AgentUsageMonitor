# Claude Keychain grant durability — evidence record

**Question:** why does the macOS "Always Allow" grant for reading Claude Code's Keychain item stop working after a few hours, on a build whose code signature does not change?

**Status: IN PROGRESS — the prompt transition is now captured for the same
running process, and the machine's duplicated Keychain search list is a
confirmed defect. The causal fix still requires the controlled scoped-query
and credential-update observation in the September 1 follow-up plan.**

Owning plan: [Claude Usage Source Durability and Refresh Defects](../superpowers/plans/2026-08-12-claude-usage-source-durability.md), Task 0.

Follow-up plan: [Claude Keychain Reprompt Durability](../superpowers/plans/2026-09-01-claude-keychain-reprompt-durability.md).

No credential bytes were read at any point. `security find-generic-password` was always run **without `-w`**, which returns attributes only, never the secret, and never prompts.

---

## Run / Observed

### O1 — The documented cause does not apply (Step 1)

| Property | Value |
|---|---|
| Bundle | `/Applications/AgentUsageMonitor.app`, `0.0.1` build `266` |
| Authority | `Developer ID Application: <maintainer> (TEAMID)` |
| Notarization | ticket stapled |
| Designated requirement | `identifier "com.david.codex-usage-monitor" and anchor apple generic and … certificate leaf[subject.OU] = TEAMID` |

The requirement is pinned to the bundle identifier and team, **not** to a cdhash, so it is stable across rebuilds. The repository's only recorded explanation for a returning prompt — ad-hoc signing, whose requirement is the binary hash and changes every build ([PR 1 note](../pr/1-claude-usage-provider.md), [README](../../README.md), [release guide](./releasing-on-github.md)) — **cannot** be the cause here.

### O2 — There is exactly one build, and it is the one running (Step 6)

```
ps  →  58485 /Applications/AgentUsageMonitor.app/Contents/MacOS/CodexUsageMonitor
mdfind "AgentUsageMonitor.app" → /Applications/AgentUsageMonitor.app   (single result)
mdfind "CodexUsageMonitor.app" → (none)
```

A second, differently-signed development build alternating with the release build would look exactly like an expiring grant. **Ruled out** — no second bundle exists on disk.

### O3 — Claude Code updates its Keychain item in place, frequently (Step 3 partial)

```
cdat = 2026-07-20T02:32:03Z      (unchanged since July)
mdat = 2026-08-13T00:53:42Z      (26 minutes before the 01:19Z sample)
```

Creation date is static while the modification date tracks recent activity, so Claude Code **rewrites the item's data rather than deleting and recreating it**. A delete-then-add would reset `cdat` and unambiguously destroy the ACL; that is not what is happening, so item recreation is not the mechanism.

### O4 — In the steady state the grant is live, for both read policies

Run at 01:19:27Z, using the app's own in-bundle probe (`--claude-live-read-once`), which executes **inside the same signed binary** and therefore against the same ACL entry as the Refresh button:

```
tier 1  OAuth live fetch  available   5h 13.0% · 7d 2.0% · plan pro · via Claude Code credentials
tier 2  CLI /usage probe  manual only
tier 3  statusLine        UNAVAILABLE — no snapshot at claude-rate-limits.json
tier 4  cached            available — source oauth · saved 2026-08-13T01:17:14Z
coordinator → delivery "live", source "oauth"
```

Two things follow:

1. **The user-initiated read completed in about one second with no dialog.** The grant was in effect.
2. **The app's own scheduled read succeeded two minutes earlier** (tier 4 shows a cache written at 01:17:14Z by the running app). A scheduled read sets `kSecUseAuthenticationUIFail`, so it can only succeed while the ACL grants access **without interaction**. The grant was therefore in effect for background reads too.

So the failure is a **transition**, not a steady state. Any explanation must account for a grant that works, then stops, while the application's code identity never changes.

### O5 — The passive tier was dead at the time of this observation

Tier 3 reported `no snapshot at claude-rate-limits.json (bridge not installed or never fired)`, confirming from inside the app what the filesystem already showed. The configured status line is:

```
cd '~/Desktop/<superseded-project-dir>/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet
```

That directory does not exist, so every Claude Code render fails silently. `ClaudeStatusLineInstaller` has no call site in application code, so the shipped app can neither install nor repair it. This is independent of the grant question but is what converts a lost grant into a blank reading instead of a slightly stale one.

This observation is historical. The later single-binary work installed the
privacy-scoped status-line bridge through the main signed executable, and the
user reported its smoke test working. The follow-up reprompt fix therefore
preserves passive/cache delivery instead of assuming OAuth is the only source.

---

### O6 — The sampler ran to completion and the grant never failed in its window

90 samples over 4.45 hours (01:20Z → 05:47Z):

| | Result |
|---|---|
| Distinct `mdat` values | **one** — `20260813005342Z`, unchanged throughout |
| Cache `savedAt` | advanced continuously, 55 distinct values |
| Longest stall | 1 sample (~3 min), i.e. normal poll spacing |
| Cache source | `oauth` on every sample |

The grant held for the whole window, and **Claude Code never rewrote its credential during it**, so the discriminator never fired. This is "the independent variable never moved", not "the hypothesis is disproven".

(The sampler's `app_running` column reads 35/90 only because its `pgrep` pattern matched the `/Applications` bundle while the running instance was the `.build` one. The cache advancing throughout proves an app was reading the whole time.)

### O7 — A three-hour Claude blackout, caught, and it was not the grant

Observed at 23:52Z the same day, without a sampler running:

```
app process              pid 99499, started 00:14:40 local — never restarted
claude-usage-cache.json  last written 20:52:45Z   ← Claude reads stopped
last-known-good.json     last written 23:51Z      ← Codex reads still working
keychain mdat            23:51:51Z                ← Claude Code rewrote the credential
now                      23:52:52Z
```

So a **continuously running** app stopped producing Claude readings for about three hours while its Codex readings continued normally, and the gap ended exactly when Claude Code rewrote its credential.

A probe run one minute after that rewrite returned tier 1 **live, with no dialog**: `5h 13.0% · 7d 11.0% · plan pro · via Claude Code credentials`. The grant was therefore intact the whole time.

**Conclusion: this blackout was the borrowed access token expiring, not the grant lapsing.** Reads returned 401 from expiry until Claude Code happened to run and refresh the token. That is defect D5 in the durability plan, now observed in the wild rather than inferred.

The cadence matters for how bad this is: the two observed rewrites are 00:53:42Z and 23:51:51Z — about **23 hours apart**. Claude Code refreshes the token only when it runs, so any stretch where the user is not using Claude Code after expiry is a stretch where this app shows stale data and cannot fix it by itself.

**This is the empirical case for delegated refresh** ([prompt-free plan, Task 1b](../superpowers/plans/2026-08-12-claude-prompt-free-credentials.md#task-1b--re-test-the-token-exchange-instead-of-shelving-it)): the app can ask Claude Code to renew its own token instead of waiting for the user to happen to use it.

### O8 — The item's attributes are readable without any authorization

An **unsigned, ad-hoc** script issuing `SecItemCopyMatching` with `kSecReturnAttributes` and **no** `kSecReturnData`:

```
OSStatus: 0
modified: 2026-08-13T23:51:51Z
created : 2026-07-20T02:32:03Z
has data field: false
```

No prompt, from a process with no grant of any kind. So the modification date is an **ACL-free, non-prompting fingerprint** of the credential — usable to detect that a refresh happened without ever reading the secret. This is the mechanism CodexBar's delegated refresh uses to confirm success, and it is confirmed working here.

### O9 — The touch command runs cleanly, but its renewal efficacy is unverified

`claude auth status --json` against the live CLI (2.1.227):

```
exit 0, 6 seconds
stdout keys: apiProvider, authMethod, email, loggedIn, orgId, orgName, subscriptionType
mdat before == mdat after
```

Two things follow.

1. **Its stdout carries account identity** — `email`, `orgId`, `orgName`. The delegated-refresh implementation discards stdout to `/dev/null` and treats the credential fingerprint as the only result, which this observation confirms is necessary rather than merely tidy.
2. **Whether it triggers a renewal is still unknown.** `mdat` did not move, but the token had been refreshed eight minutes earlier, so nothing was due. This run shows the command is safe, fast, and non-destructive; it does **not** show that it renews an expired credential.

The efficacy test requires an expired-token window — precisely the state O7 caught. CodexBar uses a heavier PTY-driven `claude /status` session rather than `auth status`, which is weak evidence that the lightweight command may not be enough. If the cheap touch proves ineffective, that PTY approach is the documented fallback.

## Still open

The prompt transition is now captured, but its causal mechanism is not yet
proven. The same running process was prompted again, ruling out a changed app
identity for those events. The duplicated global search list and the app's
classification of a noninteractive failure as revoked authorization still
confound the later reconnect prompt.

The remaining discriminator is a scoped, noninteractive read across an ordinary
credential modification. If that read continues to succeed, the app-side query
and state handling caused the false recovery path. If it persistently fails and
the same signed process prompts on an explicit reconnect, Claude Code changed
the item's access object even though its creation date stayed fixed.

---

### O10 — The same process was prompted again after Always Allow

Sanitized `securityd` ACL logs captured three cycles in one still-running
signed working-copy process. Each cycle recorded a displayed Keychain prompt
and a later user approval of **Always Allow**. The process identifier and path
remained unchanged between cycles.

This rules out process replacement, restart into the installed copy, and a new
code signature as explanations for those specific repeated prompts. Both the
working-copy and installed bundles currently share the same Developer ID
designated requirement and both pass the noninteractive sanitized OAuth probe.

### O11 — The global Keychain search list contains one Keychain 168 times

`security list-keychains -d user` reports the default login Keychain 168 times
and no other unique path. An attributes-only `SecItemCopyMatching` for the
Claude service inherited that list and returned 168 entries with identical
creation and modification dates. Adding `kSecMatchSearchList` with the single
default Keychain reduced the same query to one result.

The repository contains no call to `SecKeychainSetSearchList` and no invocation
of `security list-keychains`, so Agent Monitor did not create this machine
state. The production credential query currently inherits it, however, making
explicit single-Keychain scoping an app-level containment.

### O12 — One prompt followed a Claude credential update

The Claude item's creation date remained unchanged, while its latest observed
modification occurred about six minutes before the next recorded ACL prompt.
That is consistent with an in-place value update followed by renewed ACL
evaluation. It does not yet prove that Claude Code replaced the access object:
the duplicated global search scope and the app's collapse of temporary
`errSecInteractionNotAllowed` into durable access denial are still active
confounders.

The September 1 plan therefore tests the invariant in this order: scope the
query to one login Keychain, preserve temporary unavailability as retry-later,
then observe one normal credential modification with one stable signed process.
Only a persistent failure after those corrections can establish provider-owned
access-object replacement.

## Not run

- A scoped grant → ordinary credential modification → noninteractive re-read
  sequence. This needs the user at the keyboard to answer or observe any dialog.
- Step 5(a), keychain lock/unlock and logout/login.
- Any inspection of the item's ACL entries. There is no way to read a Keychain item's ACL without an authorization prompt, so the ACL is measured **by behaviour** — whether a non-prompting read succeeds — rather than read directly.

## Conclusions so far

1. The ad-hoc-signature explanation is **ruled out** (O1).
2. A second app identity is **ruled out** (O2).
3. Item recreation is **ruled out** as the mechanism (O3).
4. The grant is **confirmed working** for both prompting and non-prompting reads (O4), held for a continuous 4.45-hour sampled window (O6), and was still intact across the three-hour outage in O7. A later reprompt was captured in the same running process (O10), so app replacement is not its cause.
5. The app had **no working fallback** beneath the OAuth tier when O5 was
   recorded. The later single-binary status-line bridge superseded that state;
   the current fix must preserve it as the no-prompt fallback.
6. **A three-hour Claude blackout was explained, and it was not the grant** (O7): the borrowed access token expired and stayed expired until Claude Code next ran. That is D5, and it is the reason to pursue delegated refresh.
7. The credential's modification date is readable **without authorization and without prompting** (O8), so a refresh can be detected without ever touching the secret.
8. The global Keychain query is malformed by a 168-entry duplicate search list,
   while an explicit default-Keychain scope finds one item (O11). Agent Monitor
   did not create that state, but it must stop inheriting it.
9. A noninteractive `errSecInteractionNotAllowed` does not establish that the
   user revoked access. It establishes only that the attempted read could not
   complete without interaction. Background collection must not convert that
   result into a disconnected account.

The scoped-query and state-classification changes are app-side containment, not
a claim that Claude Code's ACL behavior has been proven. The controlled sequence
in the follow-up plan decides whether any provider-owned limitation remains.
