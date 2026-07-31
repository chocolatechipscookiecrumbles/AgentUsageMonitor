# PR 15 — Land the stack on main and prepare the 0.0.1 notarization

**Branch:** `feature/release-0.0.1-notarization` → `main`
**Compare:** historical private-repository comparison (branch not published)
**State: Merged and released.** GitHub PR #40 merged the branch into `main`; the
source branch was deleted after `v0.0.1` build `266` was Developer ID signed,
notarized, stapled, published, downloaded, and observed working as intended on
2026-07-31.

The scope and pre-merge evidence below are retained as the review record. The
post-release rows distinguish the user's published-artifact observation from
exhaustive states that were not individually recorded.

## Summary

- **Lands PRs 6–14 on `main`.** They merged into each other rather than up to
  `main`, so only PR 5's content actually reached it. This branch carries the whole
  stack.
- Sets `CFBundleVersion` to `266`. `254` is permanently consumed by the notarized
  pre-rename submission; `265` was superseded before submission by the
  merge-readiness corrections below.
- Closes the release review's privacy/correctness findings: collection-off purges
  decoded and persisted Token Monitor state and cancels active reads, changed
  transcript prefixes rebuild, local-data export refuses symlinks, Claude
  reconciliation honors `(messageID, requestID)` plus nested agent-progress and
  parent/sidechain boundaries, and unknown plan identifiers fall back instead of
  becoming invented product names.
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

This branch contains every non-merge content commit from all ten PR branches, so a
single merge resolves the stack. The intermediate branch tips are not all ancestors
because the merges happened sideways; content containment, not tip ancestry, is the
correct check. No re-merging of the intermediate branches is needed.

**2. Apple notarized the wrong build.** The accepted submission was
`Codex Usage Monitor` / `1.0.0` / build `254`, made before the rename and the
version change.

*Cause, stated precisely:* a notarization ticket binds to the submitted binary's
code-directory hash. `CFBundleDisplayName` and `CFBundleShortVersionString` live in
`Info.plist`, which is inside the signed bundle — editing them changes the hash.
The ticket is a receipt for one binary, not a standing for the project.

## Scope and non-goals

**Included:** `CFBundleVersion` `254 → 266`; the documentation that records the
notarization state honestly; the reviewed privacy/correctness fixes and their narrow
regressions; and reconciliation of the README, release notes, Claude verification,
active plans, operating guide, and PR evidence.

**Not included in the code review:** the final Developer ID rebuild, resubmission,
staple, tag, and release. Those steps were run manually after review and completed
on 2026-07-31; the release guide carries the repeatable sequence.

## Design and ownership

**Why `266`.** Apple tracks build numbers **per bundle identifier**, and the
identifier did not change with the rename — `com.david.codex-usage-monitor` before
and after. From the notary's side `254` is spent permanently, whatever the app now
calls itself. `265` was never submitted and is superseded by the reviewed release
fixes; `266` is the next monotonic shipping candidate.

**What the approval is still worth.** It proves the certificate and private key work
for distribution signing, that the hardened runtime, secure timestamp, and absence
of `get-task-allow` all satisfy the notary, and that the nested bridge is signed in
the right order — the usual cause of a rejection. Build `266` also contains the
reviewed release corrections in this PR, so those code changes still require their
own automated and signed-app acceptance; the earlier approval establishes only the
distribution-signing setup.

## Privacy, compatibility, and migration

**Privacy.** Collection-off now purges both sanitized persisted requests and decoded
source state before a later re-enable. Export reads only regular allowlisted files
through no-follow descriptors, and the new regressions use fabricated records only.

**Compatibility.** The bundle identifier is deliberately unchanged, so an existing
install upgrades in place and keeps preferences, the Keychain grant, quota history,
and other app-owned stores. The sanitized Token Monitor cache intentionally
invalidates schema 1 and rebuilds because Claude request identity changed.

**Migration.** The build-number increase is invisible to users. The first Token
Monitor scan after upgrading may briefly show loading while schema-2 activity is
rebuilt.

## Regression proof

The deterministic failures reproduced before the fixes were:

- a persisted-off launch retained current, prior-schema, and unreadable provider
  cache files and never reset decoded source state; a rapid off/on transition could
  admit stale scan work, and cancellation did not stop a reader already traversing
  records;
- same-inode rewrites reused stale parsed activity when their size stayed equal or
  grew after changing the previously parsed prefix;
- an allowlisted export filename symlink exported a readable JSON target outside
  Application Support;
- Claude collapsed distinct request IDs, dropped valid parent pairs when a
  sidechain replay existed, and ignored a nested agent-progress assistant;
- an unrecognized plan such as `enterprise_custom` rendered as a plausible plan.

The narrow regression classes exercise only those failures. Broader feature and
visual acceptance stays manual per repository policy.

## Verification

| Check | State | Result |
|---|---|---|
| `xcodebuild` main macOS scheme | Run | `** BUILD SUCCEEDED **` for the macOS destination |
| Full `swift test` | Run | 329 tests, 0 failures |
| Release `.app` resource/signature checks | Run | Pre-merge ad-hoc build `0.0.1` / `266`; asset catalog present; app and nested bridge passed strict signature checks |
| `plutil -p Resources/Info.plist` | Run | `Agent Monitor` / `0.0.1` / `266` |
| Stack content containment | Run | Every non-merge content commit from the ten stack branches is present |
| No content lost in the partial cascade | Run | No non-merge commit exists on any remote branch that is absent here |
| Developer ID rebuild, notarization, staple, tag, publish | Observed | User completed the manual release sequence for build `266`; `v0.0.1` is published |
| Uploaded artifact verification | Observed | User downloaded the published archive and reported the app works as intended |
| Exhaustive VoiceOver/permission/conditional-state matrix | **Not run** | The release smoke test does not identify every individual matrix state |

## Risks, rollback, and limitations

**Risk — the specific one that was controlled.** The pre-release `.build` bundle
was an ad-hoc `0.0.1` / `266` candidate, not the shipping artifact. The published
archive was produced only after the Developer ID rebuild, notarization, and staple,
then downloaded again for verification.

**Second risk considered before submission.** A rejection would most likely have
pointed to a re-used build number or stale `Info.plist`, because the signing setup
was already proven. The build was accepted, so this risk did not materialize.

**Historical rollback boundary.** Before submission the release-readiness commit
could be reverted. Build `266` has now been submitted and published, so any future
replacement must use a fresh build number rather than rewriting this release.

**Limitations.** The untracked asset catalog means a clean clone can compile and
test but cannot package the shipping `.app`; the release machine must supply the
approved local assets. The non-scrolling Token Monitor can exceed a 1280×800
screen; that is an explicit accepted 0.0.1 limitation, not a closed visual finding.
The published app passed the user's release smoke test. Exhaustive Light/Dark,
keyboard, VoiceOver, export, shortcut, provider-switch, file-event, and manufactured
conditional-state combinations remain useful ongoing verification where they were
not individually recorded. Public-repository cleanup remains tracked in
`before-going-public.md`.

## Documentation and review focus

Changed: the reviewed activity/export/plan sources and narrow regressions,
`CodexUsageMonitor/Resources/Info.plist`, release-facing and operating
documentation, the active implementation plans, and this draft.

Focus on the **merge strategy**. Merging this branch into `main` is intended to be
the single action that lands PRs 6–14; confirm that reading of the branch graph
before merging, because the alternative — re-merging nine branches bottom-up —
produces the same content by a much longer route.

## Post-release branch cleanup — 2026-07-31

After PR #40 and publication, every remaining remote feature branch was audited
against `origin/main` with both ancestry and patch-equivalence checks. The
sideways stack branches were not all ancestors, but
`git log --no-merges --cherry-pick --right-only origin/main...<branch>` returned no
unique content commits for any of them. The obsolete GitHub and matching local
branch refs were deleted.

The durable prevention rule now lives in
[Evidence-Rich Pull Requests](../development/evidence-rich-pull-requests.md#keep-stacked-pull-request-bases-moving-in-the-same-direction):
merge a true stack deepest-first, or retarget each remaining child to current
`main` after its parent merges. A green GitHub “Merged” badge proves only that the
PR reached its configured base branch.
