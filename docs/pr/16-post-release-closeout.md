# PR 16 — Record the published 0.0.1 release and future packaging work

**Branch:** `docs/post-release-closeout` → `main`
**Compare:** historical private-repository comparison (branch not published)
**State:** Ready after the documentation checks below pass.

## Summary

- Records that Agent Monitor `0.0.1` / build `266` was Developer ID signed,
  notarized, stapled, published, downloaded, and observed working as intended,
  while preserving the boundary around exhaustive unrecorded states.
- Adds two explicit future items: coherent Claude usage/plan recovery and
  consolidation of the separately signed Claude bridge into the app's single
  executable.
- Records why the earlier stacked pull requests all showed merged while several
  branch tips never became ancestors of `main`, and adds a durable prevention rule.

## Problem and root cause

After publication, release-facing documents still described build `266` as
unsubmitted, the release PR as Draft, and signed-app verification as pending.
Separately, the shipped `ClaudeUsageBridge` was often described as a “resource”
without emphasizing that it is a second executable Mach-O binary with its own
nested signing boundary.

The branch-history problem came from pull requests targeting other feature
branches. Parents were merged upward before their children landed, so later child
merges changed only an already-merged feature branch. GitHub's “Merged” state means
“merged into this PR's configured base,” not “reachable from `main`.”

## Scope and non-goals

**Included:** release status and evidence wording; product follow-ups 9 and 10;
release/planning/architecture documentation; stacked-PR workflow guardrails; the
post-release branch-cleanup record.

**Not included:** no production Swift, build script, signing, entitlement, bundle,
status-line installation, credential, or runtime behavior changes. The bridge
consolidation and connection-state repair remain unimplemented and require
dedicated plans.

## Design and ownership

The Product Planning Board remains the current status owner. Historical PRs and
implementation plans retain their original evidence, with dated closeout or
supersession notes where later facts changed.

Follow-up 10 requires one executable binary in the shipped app bundle. A future
plan must choose how the main executable enters a non-UI stdin bridge mode and how
Claude's status-line command survives app moves, upgrades, and rollback before the
separate bridge target or signing step is removed.

## Privacy, compatibility, and migration

Documentation only. No local file, credential, network, permission, persistence, or
bundle behavior changes. The future single-binary plan explicitly preserves the
existing field allowlist, owner-only atomic snapshot, status-line configuration,
and 0.0.1 upgrade/rollback boundary.

## Regression proof

Not applicable to production behavior. The documentation regression was the
presence of current-tense “not started,” “Draft,” and “release gate remains” claims
after the release was published. Repository-wide searches and local-link checks
form the narrow verification boundary.

## Verification

| Check | State | Result |
|---|---|---|
| `git diff --check` | Run | Clean |
| Release-state stale-copy search | Run | No current release document says build `266` is unpublished or awaiting notarization |
| Relative Markdown link/anchor check for changed documents | Run | Passed |
| Remote feature-branch patch audit | Run | Every deleted branch had zero non-merge patches absent from `origin/main` |
| Published artifact | Observed | User downloaded and verified `v0.0.1`; app worked as intended |
| Exhaustive VoiceOver/permission/conditional-state matrix | Not run | The user observation was a release smoke test, not an itemized matrix |

## Risks, rollback, and limitations

**Risk:** A broad “verified” statement could erase meaningful unobserved states.
The updated documents therefore name the smoke-test boundary and retain unrecorded
exhaustive checks.

**Rollback:** Revert this documentation PR if its status wording is wrong. `main`
preserves the deleted branches' patch-equivalent content, not their exact sideways
merge-tip topology. Restoring those exact refs would depend on any still-retained
GitHub PR refs or local reflogs and is not guaranteed; no unique content patch was
discarded.

**Known limitations / unrun checks:** The two future Claude changes are documented,
not implemented. This PR does not reduce the 0.0.1 bundle to one executable.

## Documentation and review focus

Review the release-state consistency, the distinction between historical and
current evidence, the stacked-PR prevention rule, and Follow-up 10's migration and
non-UI lifecycle constraints.
