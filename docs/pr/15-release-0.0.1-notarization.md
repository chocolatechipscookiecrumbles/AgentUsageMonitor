# PR 15 — Land the stack on main and prepare the 0.0.1 notarization

**Branch:** `feature/release-0.0.1-notarization` → `main`
**Compare:** historical private-repository comparison (branch not published)
**State: Ready.** Documentation plus one build-number change.

## Summary

- **Lands PRs 6–14 on `main`.** They merged into each other rather than up to
  `main`, so only PR 5's content actually reached it. This branch carries the whole
  stack.
- Sets `CFBundleVersion` to `265`. `254` is permanently consumed by the notarized
  pre-rename submission.
- Records that Apple's approval covers a build that is no longer the one being
  shipped, and what that approval does and does not establish.

## Problem and root cause

**1. The stack did not cascade.** All ten pull requests (#30–#39) were merged, but
each merged into its *base branch*, and each base had already merged upward before
its own child landed. The result is a chain where every branch holds exactly its
immediate child's merge and nothing deeper:

```
main                        ← #30 only
native-claude-bridge        ← #31
token-activity-domain       ← #32
…
agent-monitor-rename        ← #39   (contains everything)
```

*Cause:* a stacked series has to merge **bottom-up** — deepest first, each merge
completing before its parent's does. Merging top-down, or in parallel, lands one
level and stops. Nothing was lost; it simply never propagated.

`feature/agent-monitor-rename` transitively contains all ten PRs, so a single merge
of this branch resolves it. No re-merging of the intermediate branches is needed.

**2. Apple notarized the wrong build.** The accepted submission was
`Codex Usage Monitor` / `1.0.0` / build `254`, made before the rename and the
version change.

*Cause, stated precisely:* a notarization ticket binds to the submitted binary's
code-directory hash. `CFBundleDisplayName` and `CFBundleShortVersionString` live in
`Info.plist`, which is inside the signed bundle — editing them changes the hash.
The ticket is a receipt for one binary, not a standing for the project.

## Scope and non-goals

**Included:** `CFBundleVersion` `254 → 265`, and the documentation that records the
notarization state honestly — the release guide's status section, signing evidence
framing, remaining sequence, Step 1 rationale, the planning board's release row, and
blocker 2 in `before-going-public.md`.

**Not included:** the rebuild, the resubmission, the staple, the tag, and the
release. Every one of those signs, reaches the Keychain, or talks to Apple, so they
are run by hand — the release guide carries the exact sequence.

## Design and ownership

**Why `265`.** Apple tracks build numbers **per bundle identifier**, and the
identifier did not change with the rename — `com.david.codex-usage-monitor` before
and after. From the notary's side `254` is spent permanently, whatever the app now
calls itself. `265` is the commit count at this point, matching the rule already in
the release guide: monotonic without a second thing to remember.

**What the approval is still worth.** It proves the certificate and private key work
for distribution signing, that the hardened runtime, secure timestamp, and absence
of `get-task-allow` all satisfy the notary, and that the nested bridge is signed in
the right order — the usual cause of a rejection. The resubmission changes two
strings and a build number, so the risk was in the first submission, not this one.

## Privacy, compatibility, and migration

**Privacy.** Not applicable.

**Compatibility.** The bundle identifier is deliberately unchanged, so an existing
install upgrades in place and keeps preferences, the Keychain grant, quota history,
and the token cache.

**Migration.** A build-number increase is invisible to users.

## Regression proof

Not applicable — a version string and documentation. There is no old failure to
reproduce, and the test suite asserts nothing about `Info.plist` values.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` on this branch | Run | Build complete |
| `swift test` on this branch | Run | 316 tests, 1 skipped, 0 failures |
| `plutil -p Resources/Info.plist` | Run | `Agent Monitor` / `0.0.1` / `265` |
| Stack containment — every merged branch reachable from this one | Run | `git merge-base --is-ancestor` confirms all ten |
| No content lost in the partial cascade | Run | No non-merge commit exists on any remote branch that is absent here |
| Rebuild, resubmission, staple | **Not run** | By design — run by hand, see the release guide |
| Signed-app acceptance of the renamed copy | **Not run** | Still open from PR 13 |

## Risks, rollback, and limitations

**Risk — the specific one to watch.** The approved `1.0.0` bundle is still sitting
in `.build` from the 2026-07-29 run. Packaging from that directory without
rebuilding would upload a `.app` calling itself Codex Usage Monitor `1.0.0` under a
release tagged `v0.0.1` for Agent Monitor, and it would pass Gatekeeper, so nothing
would flag it. Delete it, or rebuild before packaging.

**Second risk.** If the resubmission is rejected, the cause is almost certainly not
the signing setup — that is now proven — but a re-used build number or a stale
`Info.plist` picked up by the build. `xcrun notarytool log <id>` names the actual
cause.

**Rollback.** Revert. The build number returns to `254`, which is unusable, so a
revert would need its own bump.

**Limitations.** The repository still is not fit to be public: no `LICENSE`,
personal coursework at the root, screenshots uncommittable, and the repository name
matching neither the old nor the new product name. All tracked in
`before-going-public.md`.

## Documentation and review focus

Changed: `CodexUsageMonitor/Resources/Info.plist`,
`docs/development/releasing-on-github.md`,
`docs/development/before-going-public.md`, `docs/product/planning-board.md`, and
this file.

Focus on the **merge strategy**. Merging this branch into `main` is intended to be
the single action that lands PRs 6–14; confirm that reading of the branch graph
before merging, because the alternative — re-merging nine branches bottom-up —
produces the same content by a much longer route.
