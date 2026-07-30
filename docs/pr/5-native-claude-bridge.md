# PR 5 — Replace the Python Claude bridge with a native Swift executable

**Branch:** `feature/native-claude-bridge` → `main` · 2 commits, 21 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 1 of 10 — merge first. Everything after this builds on it.
**State: Ready** for the code change; the signed-app check below is the one gap.

## Summary

- Removes the app's `python3` runtime dependency: the Claude statusLine bridge is
  now a native Swift executable, bundled and signed inside the `.app`.
- Splits the pure logic into `ClaudeUsageBridgeCore` so it can be tested without
  a process.
- Adds the first macOS release guide (`docs/development/releasing-on-github.md`).

## Problem and root cause

**Symptom.** A clean Mac could not run the app's Claude path. The bridge that turns
a Claude Code statusLine payload into the snapshot the app reads was a Python
package invoked as `python3 -m claude_usage_bridge`. macOS no longer ships a
`python3` a user can rely on, so the dependency was a real install blocker, not a
theoretical one.

**Cause.** The bridge was written during the research phase, when running it by hand
was the point. It was never revisited when the Claude provider became a shipped
feature.

## Scope and non-goals

**Included:** `ClaudeUsageBridgeCore` (decode statusLine payload → extract rate-limit
windows → atomic write), the `ClaudeUsageBridge` executable target, `Package.swift`
wiring, bundling and nested signing in `build-app.sh`, deletion of the Python
package and its tests, and the release guide.

**Not included:** any change to what the app reads or how often; interactive
one-click statusLine configuration (still deferred); the OAuth path, which is
unaffected.

## Design and ownership

`ClaudeUsageBridgeCore` holds the logic and owns nothing stateful, so its behavior
is directly testable. `ClaudeUsageBridge` is a thin executable over it. The app
copies the bundled binary to app-owned Application Support before invoking it.

`build-app.sh` signs **inside-out** — the nested helper first, the app last —
because notarization rejects an unsigned nested Mach-O, and because any change to
bundle contents after signing invalidates the signature.

## Privacy, compatibility, and migration

**Privacy.** This *removes* a runtime dependency rather than adding one. The bridge
reads the same statusLine payload and writes the same
`claude-rate-limits.json`; no new file, field, or network call.

**Compatibility.** Claude Code's statusLine payload shape is externally controlled.
The Swift decoder accepts the same shape the Python one did, verified against the
recorded fixtures.

**Migration.** Existing statusLine configurations that point at the Python module
keep working only if Python is present; the installer now resolves the native
binary. A user who had it working continues to, and a user who did not now can.

## Regression proof

Not a bug fix — a dependency removal. The port carries the decode and write tests
across from the Python suite into `ClaudeUsageBridgeCoreTests`, so the same payload
shapes (valid, partial, malformed, missing windows) are still asserted, now in the
language that ships.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | See the stack verification table in PR 14 |
| `swift test` at this branch tip | Run | See the stack verification table in PR 14 |
| Bundled bridge present and signed inside the `.app` | Run | `Scripts/verify-signed-app-resources.sh` passes |
| Claude reading end to end on a machine without `python3` | **Not run** | The development machine has Python installed, so the removal is proven by construction and by the absence of any `python3` invocation, not by a negative-environment test |

## Risks, rollback, and limitations

**Risk.** A statusLine payload shape the Swift decoder rejects but the Python one
tolerated would silently drop the fallback tier. The OAuth tier is primary, so the
user-visible effect is degraded freshness, not a wrong number.

**Rollback.** Revert. The Python package is restored by the revert; nothing
persisted changes format.

**Limitation.** Interactive one-click statusLine configuration remains deferred.

## Documentation and review focus

Changed: `docs/development/releasing-on-github.md` (new), the statusLine bridge
plan, `UsageProbe/README.md`.

Focus on the **nested signing order** in `build-app.sh`. If the helper is ever
signed after the app, notarization fails in a way that is not obvious from the
build output.
