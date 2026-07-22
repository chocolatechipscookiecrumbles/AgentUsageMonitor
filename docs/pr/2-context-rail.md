# PR 2 — Multi-provider context rail

**Branch:** `feature/context-rail` → `main`
**Merge after:** PR 1 (`feature/claude-usage-provider`) — this builds on it.

## What this does

Turns the Settings context rail from one card describing the *selected* agent into **one status block per active provider**, showing the numbers the rail is actually opened for.

| Row | Before | After |
|---|---|---|
| header | icon + state | icon **+ provider name** ("Codex" / "Claude") |
| `Current` | "OpenAI Codex" | **removed** — restated the page you were already on |
| Plan | ✓ | unchanged |
| Five-hour | — | **added** |
| Weekly | — | **added** |
| `Quota status` | refresh mode | **repurposed** → `Connected` / `Disconnected` |
| Last refresh | — | **added** |

## Correctness fix, not just a redesign

The Claude branch still rendered a **"Preview / Not available yet"** card asserting this app *"does not read its files, credentials, usage, or account data."* That stopped being true when Claude went live — a false privacy claim in shipped UI. It is deleted.

## Decisions

- **All active providers, always** — the rail no longer tracks the selected agent; it is an at-a-glance comparison. Copilot stays absent until its capability gate passes.
- **"Last refresh" is the last *successful* data timestamp** — Codex's `lastConfirmedAt`, not `lastAttemptAt`. Showing the attempt would describe a provider whose refreshes are failing as recently refreshed.
- **Absent values render "Unavailable"**, disconnected reads "Disconnected". A test asserts neither ever becomes `0%` — the rail is the easiest place in the app to invent a quota.

Both providers share one `RelativeTimeText` formatter (extracted from `ClaudeUsageDisplayModel`) with a test pinning their output equal, so wording cannot drift.

## Testing

178 tests, all green. App verified to launch.

## Not done

The rail has not been viewed rendered — two stacked cards at the fixed `contextRailWidth` may need spacing attention.
