# Claude Keychain grant durability — evidence record

**Question:** why does the macOS "Always Allow" grant for reading Claude Code's Keychain item stop working after a few hours, on a build whose code signature does not change?

**Status: IN PROGRESS — the previously documented cause is ruled out, the grant is confirmed live in the steady state, and the transition has not yet been captured.**

Owning plan: [Claude Usage Source Durability and Refresh Defects](../superpowers/plans/2026-08-12-claude-usage-source-durability.md), Task 0.

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

### O5 — The passive tier is dead, which is why a lost grant becomes "no usage data"

Tier 3 reported `no snapshot at claude-rate-limits.json (bridge not installed or never fired)`, confirming from inside the app what the filesystem already showed. The configured status line is:

```
cd '~/Desktop/<superseded-project-dir>/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet
```

That directory does not exist, so every Claude Code render fails silently. `ClaudeStatusLineInstaller` has no call site in application code, so the shipped app can neither install nor repair it. This is independent of the grant question but is what converts a lost grant into a blank reading instead of a slightly stale one.

---

## In flight

A sampler records `mdat`, the app's cache `savedAt`, the cache source, and whether the app is running, every three minutes. Because the app's scheduled read is non-prompting, **the cache timestamp advancing is a direct assertion that the grant still works**; it stalling while the app is alive marks the moment the grant died, and the concurrent `mdat` value says whether a Claude Code credential rewrite coincided with it.

Expected discriminator:

- `savedAt` stalls **immediately after** an `mdat` advance → the grant is invalidated by another process rewriting the item.
- `savedAt` stalls with `mdat` unchanged → the trigger is time- or session-based (keychain relock, login-session change), not the rewrite.
- `savedAt` never stalls → the grant did not fail during the window; the reported symptom must be reproduced by a different route before any fix is designed.

## Not run

- Steps 2 and 4 (grant, then re-read after a forced rewrite) as an **interactive** sequence — these need the user at the keyboard to answer or observe a dialog.
- Step 5(a), keychain lock/unlock and logout/login.
- Any inspection of the item's ACL entries. There is no way to read a Keychain item's ACL without an authorization prompt, so the ACL is measured **by behaviour** — whether a non-prompting read succeeds — rather than read directly.

## Conclusions so far

1. The ad-hoc-signature explanation is **ruled out** (O1).
2. A second app identity is **ruled out** (O2).
3. Item recreation is **ruled out** as the mechanism (O3).
4. The grant is **confirmed working** in the steady state for both prompting and non-prompting reads (O4), so the reported reprompting is a transition that must be caught in the act.
5. Independently of all of the above, the app has **no working fallback** beneath the OAuth tier (O5), which is the difference between "slightly stale" and "nothing".

**Do not build a workaround for a cause that has not reproduced.** The durability work in the owning plan — reviving the keychain-free passive tier, and moving to an app-owned token — is justified by O5 and by the read-path defects, and does not depend on this question being answered.
