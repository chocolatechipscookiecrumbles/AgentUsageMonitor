# PR 16 — Record the 0.0.1 release, known bugs, and follow-up work

**Branch:** `docs/post-release-closeout` → `main`
**Compare:** historical private-repository comparison (branch not published)
**State:** Ready after the documentation checks below pass.

## Summary

- Records that Agent Monitor `0.0.1` / build `266` was Developer ID signed,
  notarized, stapled, published, downloaded, and observed working as intended,
  and adopts **AgentUsageMonitor** as the project/local clone name while keeping the
  GitHub repository name and working endpoint `agent-usage` explicit.
- Records five unresolved release follow-ups without inventing causes: Claude
  usage/plan reconciliation, single-binary bridge packaging, missing Codex local
  token activity, problematic Claude setup, and an explicit first-launch
  connection-consent policy.
- Records why the earlier stacked pull requests all showed merged while several
  branch tips never became ancestors of `main`, adds a durable prevention rule,
  and credits the open-source projects that informed the work.

## Problem and root cause

After publication, release-facing documents still described build `266` as
unsubmitted, the release PR as Draft, and signed-app verification as pending.
Separately, the shipped `ClaudeUsageBridge` was often described as a “resource”
without emphasizing that it is a second executable Mach-O binary with its own
nested signing boundary.

The released app also exposed two user-observed problems that had not been
recorded: Codex Token Monitor can fail to publish local usage, and Claude setup can
require unclear extra recovery. Their root causes are not yet known. Separately,
the requested connection hardening makes the first-launch consent boundary
explicit: on a fresh installation, both providers should start app-locally
disconnected and require independent Connect actions before quota collection.

The requested GitHub endpoint
`chocolatechipscookiecrumbles/AgentUsageMonitor` returned “Repository not found”
on 2026-07-31, while the existing `agent-usage` endpoint remains operational.
README presentation and local clone naming now use `AgentUsageMonitor`, but URLs
remain on the verified endpoint until the remote rename actually exists.

The branch-history problem came from pull requests targeting other feature
branches. Parents were merged upward before their children landed, so later child
merges changed only an already-merged feature branch. GitHub's “Merged” state means
“merged into this PR's configured base,” not “reachable from `main`.”

## Scope and non-goals

**Included:** release status and evidence wording; product follow-ups 9 through 13;
the `AgentUsageMonitor` project-name boundary;
release/planning/architecture documentation; accurate inspiration/research
attribution for CodexBar, ccusage, Token Monitor, and Tokscale; stacked-PR workflow
guardrails; the post-release branch-cleanup record.

**Not included:** no production Swift, build script, signing, entitlement, bundle,
status-line installation, credential, local-activity, first-launch, or runtime
behavior changes. Every newly recorded release bug remains unfixed and requires
diagnosis before an implementation plan.

## Design and ownership

The Product Planning Board remains the current status owner. Historical PRs and
implementation plans retain their original evidence, with dated closeout or
supersession notes where later facts changed.

Follow-up 10 requires one executable binary in the shipped app bundle. A future
plan must choose how the main executable enters a non-UI stdin bridge mode and how
Claude's status-line command survives app moves, upgrades, and rollback before the
separate bridge target or signing step is removed.

Follow-ups 11 through 13 keep local-activity discovery, Claude setup, and
provider-connection consent as distinct owners. A Token Monitor read failure must
not be misclassified as authentication disconnection, and connecting one provider
must not connect or mutate the other.

## Privacy, compatibility, and migration

Documentation only. No local file, credential, network, permission, persistence, or
bundle behavior changes. The future single-binary plan explicitly preserves the
existing field allowlist, owner-only atomic snapshot, status-line configuration,
and 0.0.1 upgrade/rollback boundary.

## Regression proof

Not applicable to production behavior. The documentation regression was the
presence of current-tense “not started,” “Draft,” and “release gate remains” claims
after the release was published, plus omission of the newly reported 0.0.1 bugs.
Repository-wide searches and local-link checks form the narrow verification
boundary; no runtime regression is claimed fixed.

## Verification

| Check | State | Result |
|---|---|---|
| `git diff --check` | Run | Clean |
| Release-state stale-copy search | Run | No current release document says build `266` is unpublished or awaiting notarization |
| Relative Markdown link/anchor check for changed documents | Run | Passed |
| Remote feature-branch patch audit | Run | Every deleted branch had zero non-merge patches absent from `origin/main` |
| `git ls-remote` for `AgentUsageMonitor` | Run | Destination returned “Repository not found”; working URLs intentionally remain `agent-usage` |
| Published artifact | Observed | User downloaded and verified `v0.0.1`; app worked as intended |
| Published-release defects | Observed | User reported missing Codex local token usage and problematic Claude setup; root causes remain undiagnosed |
| First-launch connection policy | Requested | A fresh installation should start both providers app-locally disconnected and require separate explicit Connect actions before quota collection |
| Open-source attribution | Run | README and release notes credit CodexBar, ccusage, Token Monitor, and Tokscale as inspiration/research references without claiming endorsement, bundling, or direct contribution |
| Attribution repository links | Run | All four direct GitHub repository pages resolved publicly on 2026-07-31 |
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

**Known limitations / unrun checks:** Follow-ups 9 through 13 are documented, not
implemented. This PR neither fixes the two release bugs, implements the requested
first-launch connection policy, nor reduces the 0.0.1
bundle to one executable. The GitHub repository endpoint has not yet been renamed.

## Documentation and review focus

Review the release-state consistency, the distinction between historical and
current evidence, the absence of invented root causes for Follow-ups 11–13, the
working-versus-target repository naming boundary, the stacked-PR prevention rule,
and Follow-up 10's migration and non-UI lifecycle constraints.
