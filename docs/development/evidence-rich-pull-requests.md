# Evidence-Rich Pull Requests

This is the repository's source of truth for turning an idea, bug fix, or UI change into a focused pull request whose claims a reviewer can verify.

A good PR is not a diary of everything the author did. It is a compact argument:

> This observable problem existed, this change addresses its actual cause, and this evidence shows both the intended result and the remaining uncertainty.

Use the repo-local `preparing-evidence-rich-prs` skill when drafting or updating a PR. The skill supplies the short workflow; this guide explains the reasoning and the repository-specific evidence gates.

Branch creation, commit identity, pre-push privacy checks, public/private promotion,
and history-rewrite incident response follow the
[public update workflow](public-update-workflow.md).

## Contents

- [The development loop](#the-development-loop)
- [Before implementation](#before-implementation)
- [Build a reviewable change](#build-a-reviewable-change)
- [The PR contract](#the-pr-contract)
- [Draft versus ready for review](#draft-versus-ready-for-review)
- [Regression tests](#regression-tests)
- [Repository-specific regression strategies](#repository-specific-regression-strategies)
- [Verification evidence](#verification-evidence)
- [Review and follow-up](#review-and-follow-up)
- [Worked example](#worked-example)
- [Final checklist](#final-checklist)

## The development loop

The useful part of a neighboring project's process is not its exact toolchain. It is the progression from uncertain idea to reviewable evidence.

1. **Frame the user problem.** State one user job and one observable outcome. “Copy feature X” is not a problem statement.
2. **Gather evidence.** Reproduce current behavior, find the local owner, inspect relevant history and plans, and compare independent implementations when useful.
3. **Generate options.** Include doing nothing, a narrow native solution, and an integration when those are credible choices. Compare privacy, compatibility, operating cost, and maintenance.
4. **Record the decision.** Use an ADR for a durable ownership, architecture, protocol, privacy, or dependency decision. Record rejected alternatives and why.
5. **Probe unknowns.** Answer uncertain file shapes, CLI behavior, framework propagation, or performance assumptions in a small probe before production code.
6. **Plan a tracer bullet.** Connect one source through one typed contract to one user-visible result and its acceptance evidence.
7. **Implement in reviewable increments.** Keep ownership and compatibility boundaries explicit. Update the active implementation plan when evidence, scope, limitations, or verification changes.
8. **Prove the regression boundary.** Add the smallest deterministic example of the old failure where automated tests are allowed.
9. **Verify in the real environment.** Build and inspect the signed macOS app for native menu, Settings, permission, notification, and appearance behavior.
10. **Prepare the PR as an evidence index.** Explain the problem, cause, design, regression proof, exact verification, limitations, risk, and rollback.
11. **Review and reflect.** Resolve feedback with new evidence, then record only durable lessons that would change a future decision.

This loop is intentionally asymmetrical: exploration may be broad, but the merged change should be narrow.

## Before implementation

### Start with an observable outcome

Prefer:

> During one continuing refresh interruption, the user receives at most one disconnection-style notification, including after relaunch.

Avoid:

> Refactor notification state.

The first statement gives the author and reviewer a behavioral boundary. The second names an activity but supplies no acceptance criterion.

### Find the owner before adding a helper

Trace the full path that produces the behavior:

```text
source event -> domain state -> policy -> persistence/deduplication -> presentation -> platform delivery
```

For UI work, continue through the native boundary:

```text
published state -> view model -> SwiftUI observation -> AppKit window/menu -> visible interaction
```

Record where the invariant belongs. A PR that moves a counter or cache should explain why the new owner is authoritative and which previous duplicate ownership is removed.

### Separate research from adoption

When another project informs the design, identify the relationship:

- **Research:** concepts and failure cases only.
- **Comparison oracle:** the same sanitized input is evaluated by two independent tools.
- **Runtime dependency:** the application invokes or bundles another tool.
- **Adapted source:** implementation is ported or modified under its license.

A PR must add provenance, license, update, security, privacy, failure-UX, and compatibility evidence in proportion to the relationship. “The repository has an MIT badge” is not enough evidence to bundle it.

### Use the right durable document

| Information | Durable home |
|---|---|
| User problem, scope, milestones, changing evidence | Active implementation plan |
| Durable architecture or ownership decision | ADR |
| Always-on repository invariant | Nearest `AGENTS.md` |
| Repeatable task workflow | Repo-local skill |
| User-visible operation or limitation | `UsageProbe/README.md` and/or `docs/development/operating-notes.md` |
| Review-specific evidence and risk | Pull request |

Do not turn `AGENTS.md` into a project tour. Put only durable traps and routing there.

## Build a reviewable change

### Keep the branch focused

Before editing, inspect the branch, status, active plan, and relevant `AGENTS.md` files. Preserve user-owned changes. If the current checkout contains unrelated work, prepare the PR in an isolated worktree or another clean checkout rather than sweeping unrelated files into the commit.

A focused PR should let a reviewer answer:

- Which behavior changes?
- Which files are incidental?
- Can the change be reverted without losing unrelated work?

### Prefer vertical slices

A reviewable slice connects behavior end to end. For example:

```text
failed refresh
  -> QuotaMonitor interruption episode
  -> stable persisted episode ID
  -> notification policy transition
  -> one delivery key
  -> recovery closes the episode
```

A horizontal “add all infrastructure” PR usually hides whether any user outcome works.

### Keep stacked pull-request bases moving in the same direction

GitHub merges a pull request into the base branch named on that pull request. It
does not remember that the base branch previously merged into `main`, and a later
merge into that old base does not propagate upward automatically.

For branches `A <- B <- C`, use one of these two safe workflows:

1. Keep the stack intact and merge deepest first: `C` into `B`, then `B` into `A`,
   then `A` into `main`.
2. Merge `A` into `main`, then retarget `B` from `A` to current `main`, verify the
   new comparison, merge it, and repeat for `C`.

Do not merge parents top-down while leaving their children based on already-merged
feature branches. Every GitHub PR can show “Merged” while `main` still contains
only the first layer.

Before a release or branch deletion:

```sh
git fetch origin --prune
git merge-base --is-ancestor origin/feature/example origin/main
git log --no-merges --cherry-pick --right-only \
  --oneline origin/main...origin/feature/example
```

The ancestry check proves the branch tip actually landed. The cherry-equivalence
check catches sideways/squashed histories where the tip is not an ancestor but no
content patch remains unique. Investigate any listed commit before deleting the
branch. Also open the GitHub comparison against `main`; an empty or already-landed
content comparison is the human-readable cleanup boundary.

### Update the plan while evidence changes

The implementation plan is not a ceremonial preface. Update it when:

- the root cause differs from the initial theory;
- scope grows or shrinks;
- a compatibility or privacy boundary is discovered;
- a required check cannot be run;
- signed-app acceptance exposes a limitation;
- the implementation deliberately defers part of the original outcome.

## The PR contract

Use `.github/pull_request_template.md` as the concise body. Expand only the sections that carry meaningful evidence for this change.

### 1. Title

Name the user-visible or architectural outcome, not the activity:

- Good: `Prevent repeated interruption notifications across relaunches`
- Weak: `Refactor notification manager`

### 2. Summary

In two or three bullets, state:

- what changes for the user or maintainer;
- the important design choice;
- any intentionally deferred outcome.

### 3. Problem and root cause

Separate symptom from cause.

- **Symptom:** what was observed, under which conditions, and with what impact.
- **Root cause:** the ownership, state-transition, parsing, scheduling, propagation, or compatibility mechanism that produced it.
- **Evidence:** reproduction steps, logs, fixture, source trace, measurement, or screenshot that supports the conclusion.

If the cause is still a hypothesis, call it a hypothesis and keep the PR Draft.

### 4. Scope and non-goals

List the behavior and files intentionally included. State adjacent work that is deliberately excluded. This is where a narrow native implementation stays distinct from a neighboring all-purpose tool.

### 5. Design and ownership

Describe only the parts a reviewer needs to reason about:

- authoritative owner and typed contract;
- state transitions and recovery boundary;
- persistence, cache, or deduplication keys;
- observation and native presentation boundary;
- compatibility surface and fallback behavior.

For a small docs change, one sentence may be enough. Proportionality is part of quality.

### 6. Privacy, security, compatibility, and migration

Answer each relevant question and write “Not applicable” for the rest:

- Does this read new local files or fields?
- Could prompt, response, path, account, or session content leave the machine?
- Does it add a process, package, network request, permission, credential, or update channel?
- Which CLI, file schema, macOS version, persistence schema, or public API can vary?
- What happens to existing saved state after upgrade and rollback?

Dependency, authentication, privacy, and migration changes need more evidence than copy or documentation changes.

### 7. Regression proof

Name the old failure in one sentence. Then identify:

- the narrow automated example, if allowed;
- how it was shown to fail for the expected reason on pre-fix code;
- how it passes on the fixed code;
- what still requires signed-app or manual acceptance.

Do not write “tests added” without explaining what old failure they catch.

### 8. Verification evidence

Use exact commands, results, and evidence state. Never infer an unobserved UI result from compilation.

| Check | Evidence state | Result |
|---|---|---|
| `swift test --filter ...` | Run | Passed: 1 test, 0 failures |
| `CodexUsageMonitor/Scripts/build-app.sh` | Run | Signed app built successfully |
| Light -> System under macOS Dark | Observed | One live window; chrome and content both Dark; selection preserved |
| Dark appearance audit | Not run | No access to required appearance state; PR remains Draft |

Use only these labels:

- **Run:** an exact command or automated check was executed and its result inspected.
- **Observed:** a human directly inspected or exercised the real behavior.
- **Not run:** the check was not performed; state why and whether it blocks readiness.

### 9. Risk, rollback, and limitations

Identify the most credible failure mode, not every imaginable risk. State the narrow rollback:

- revert the PR;
- disable a feature flag;
- restore a previous persistence reader;
- remove the integration while preserving user data.

State limitations plainly. A known unverified state belongs here and in the active plan.

### 10. Documentation and review focus

List changed plans, ADRs, operating docs, and agent instructions. Point reviewers to the riskiest ownership decision or evidence gap instead of asking for a generic review.

## Draft versus ready for review

Open a **Draft PR** when collaboration or remote CI is useful but a required claim is not yet supported. Common reasons include:

- root cause is still hypothetical;
- regression proof has not been shown against pre-fix behavior;
- required signed-app acceptance is incomplete;
- privacy, license, dependency, or migration review is outstanding;
- the branch still includes unrelated files;
- the implementation plan records a blocking limitation.

Mark **Ready for review** only when:

- scope and non-goals are stable;
- the root cause and ownership change are defensible;
- required automated checks have passed, or their absence is an explicitly accepted project constraint;
- required real-app checks were directly observed;
- compatibility, privacy, and migration consequences are covered;
- plan and user documentation reflect actual behavior;
- the PR can be reverted without discarding unrelated work.

“The code compiles” is not a readiness rule.

## Regression tests

### What a regression test proves

A regression test is an executable example of a previously broken behavior. Its strongest form supplies three pieces of evidence:

1. **Reproduction:** the test input recreates the old failure.
2. **Discrimination:** the test fails on the pre-fix implementation for the expected reason.
3. **Protection:** the same test passes after the fix.

A new test that passes only on current code may be useful, but it has not yet demonstrated that it guards the reported regression.

### Related test types

| Type | Purpose | What it does not prove by itself |
|---|---|---|
| Test-driven test | Written before implementation to drive the design | Real platform presentation or permissions |
| Regression test | Locks down a known old failure | Broad correctness outside its case |
| Characterization test | Records existing behavior before a risky change | That the existing behavior is desirable |
| Integration test | Exercises multiple real components together | Native UI geometry if it stops below AppKit |
| Manual acceptance | Directly exercises real user-visible platform behavior | Repeatable automated protection |

Do not claim test-driven development if the implementation existed before the test. Say that a regression test was added and describe how it was validated.

### How to prove the old test fails safely

When the fix already exists, use a disposable worktree or clean checkout at the base/pre-fix commit:

1. Apply only the new test or fixture to the pre-fix commit.
2. Run the narrow test.
3. Confirm it fails for the expected behavioral assertion, not because the test does not compile.
4. Run the same test on the fixed branch and confirm it passes.
5. Record both commands and summarized results in the PR.

An alternative is to reverse only the minimal fix locally, run the test, then restore it. Use that only when restoration is safe and cannot disturb user work. Never rewrite or reset a dirty user checkout to manufacture regression evidence.

### Properties of a useful regression test

A useful regression test is:

- behavioral rather than coupled to private implementation calls;
- narrow enough that its failure explains something;
- deterministic in time, ordering, file discovery, locale, and random input;
- based on the public or intended module seam;
- backed by a small sanitized fixture when parsing external data;
- explicit about missing, stale, partial, duplicated, and recovery states;
- named after the behavior that must never return.

Avoid tests that:

- assert only that a mock method was invoked;
- pass on the buggy implementation without explanation;
- ingest a user's real logs or secrets;
- snapshot large irrelevant structures;
- depend on wall-clock sleeps, global machine state, or unstable file ordering;
- prove only a SwiftUI hosting harness when the bug lives in `MenuBarExtra` or `NSWindow` behavior.

## Repository-specific regression strategies

### Parser and local usage collection

Use small, sanitized fixtures for each externally controlled record shape. A high-value matrix includes:

- one valid record;
- unknown additive fields;
- missing optional and required fields;
- truncated final JSONL record while a writer is active;
- repeated scan of an unchanged file;
- append after an initial scan;
- rotated, moved, or deleted file;
- inconsistent model identifiers;
- token totals near integer boundaries;
- privacy sentinels proving prompt and response text do not enter the normalized snapshot.

For comparison-oracle tests, record tool version, exact command, fixture hash, normalization rules, and any discrepancy. Agreement with Tokscale or ccusage is evidence, not the product contract.

### Refresh interruption notifications

Exercise the episode, not just the first alert:

1. failures one and two produce no interruption notification;
2. failure three creates one durable episode and one eligible delivery;
3. later ten-minute retries do not create new episode or delivery keys;
4. relaunch preserves the same episode and deduplication state;
5. manual retry failure does not imply recovery;
6. a confirmed result closes the episode and restores the selected cadence;
7. a later interruption creates a new episode;
8. setup/authentication failures remain on the connection path and do not consume the episode threshold;
9. stale-data alerts do not overlap the active interruption cause.

The test seam should drive typed monitor state and inspect policy decisions. It should not require delivering a real system notification for every deterministic case.

### Quota and cache behavior

Cover confirmed, cached, unconfirmed, unavailable, and recovery transitions. Include repeated samples, empty responses, provider errors, stale cache boundaries, and clock-controlled scheduling. Assertions should distinguish a real zero from a missing value.

### Settings and native menu behavior

Automated tests can cover state transitions, presentation values, layout metrics, and stable row models. They cannot alone prove:

- macOS `Form`/label clipping at the signed app's default window size;
- `NSWindow.appearance` propagation in the live Settings window;
- native `MenuBarExtra` tracking, highlight, hit testing, placement, or crash safety;
- Accessibility- or permission-dependent recovery paths;
- Light/Dark contrast in every affected destination.

Those require the signed `.app` and the manual acceptance sequences in `AGENTS.md`. Record each state directly observed and each state not run. An isolated `NSHostingView` harness is diagnostic evidence, not final acceptance.

### When automated tests are currently disallowed

Do not silently add or run application tests against an explicit project instruction. Instead:

- document the smallest test that should exist;
- keep deterministic and platform-manual checks separate;
- write a step-by-step manual regression matrix;
- label it **manual acceptance**, not automated regression coverage;
- keep the PR Draft if missing automated protection violates the agreed readiness bar;
- record the limitation in the implementation plan and PR.

Manual repetition can lower immediate risk. It does not prevent the bug from returning in a later change.

## Verification evidence

### Match evidence to the claim

| Claim | Minimum useful evidence |
|---|---|
| Parser accepts a partial final record | Focused sanitized fixture; old fail/new pass |
| One outage alerts once across relaunch | Episode transition tests including persistence |
| Settings appearance changes live | Signed app; required transition matrix directly observed |
| Native menu text updates without broken commands | Signed app; open-menu transitions, pointer/command checks, soak, crash-report inspection |
| Dependency is safe to ship | Pinned version/interface, license and transitive review, provenance, update/failure/rollback plan |
| Performance improved | Same fixture/environment, before/after measurements, enough repetitions to explain variance |

### Keep commands and observations honest

Good:

> Run: `CodexUsageMonitor/Scripts/build-app.sh` — exit 0; signed app created. Observed: Light -> System under macOS Dark in the same window; destination and focus preserved. Not run: system appearance flip while the menu remained open.

Weak:

> Tested manually and everything works.

The good version tells a reviewer what can be trusted and what still needs attention.

## Review and follow-up

### Self-review before requesting review

Inspect the final diff, not only the files you remember editing:

- Does every changed file serve the stated scope?
- Does the PR explain behavior, not implementation trivia?
- Are root cause and evidence separated from initial theory?
- Does the regression case detect the old bug?
- Are exact checks and unrun states recorded?
- Are privacy, compatibility, migration, and rollback proportional to risk?
- Are plan, ADR, operating docs, and agent instructions consistent?

### Handle review feedback as hypotheses

For each comment:

1. Identify the underlying concern.
2. Verify it against the code, contract, platform behavior, or documented requirement.
3. Implement a focused change when the concern is valid.
4. Explain evidence when the suggestion would violate an invariant or solve a different problem.
5. Rerun the narrow affected checks and any coupled platform acceptance.
6. Update the PR body when risk, scope, evidence, or limitation changes.

Keep follow-up commits small enough to review. Do not mark a thread resolved merely because code changed; resolve it when the concern and evidence are addressed.

## Worked example

The following is intentionally concise enough for a real PR while still carrying the important evidence.

### Title

`Prevent repeated interruption notifications across relaunches`

### Summary

- Makes `QuotaMonitor` the sole owner of refresh-interruption episodes.
- Persists one stable episode identifier until a confirmed refresh recovers.
- Removes the notification policy's parallel failure counter and retry-derived delivery keys.

### Problem and root cause

After the third failed operational refresh, later retries could generate another disconnection-style notification. Relaunching could also lose agreement between scheduling and notification state.

The monitor and notification policy counted failures independently. The delivery key was derived from a growing failure bucket, so one continuing interruption appeared to be several alertable events.

### Scope and non-goals

Included: operational refresh interruption state, persistence, notification eligibility, and recovery. Excluded: setup/authentication alerts, stale data caused by another condition, and notification copy redesign.

### Design and ownership

`QuotaMonitor` creates one typed interruption episode after three consecutive operational failures. Failed retries preserve it. A confirmed result closes it. Notification policy consumes transitions and the stable episode ID but owns no counter.

### Regression proof

`testContinuingInterruptionDeliversOnceAcrossRetriesAndRelaunch` drives three failures, additional retries, persisted-state reconstruction, and recovery. Applied alone to the base commit, it failed because two delivery keys were produced. On this branch it passes with one delivery key until confirmed recovery; a later episode receives a new key.

### Verification

| Check | State | Result |
|---|---|---|
| Focused episode policy test | Run | Base: failed at delivery-count assertion (`2 != 1`); branch: passed |
| Full allowed deterministic suite | Run | Passed; command and count included in actual PR |
| Signed app build | Run | `build-app.sh` completed successfully |
| Failures 1, 2, 3, retry, relaunch, manual retry, recovery | Observed | One alert during the episode; recovery restored selected cadence |
| Notification-denied state | Not run | Requires resetting system permission; PR remains Draft |

### Risk and rollback

Risk: corrupted legacy episode state could suppress one alert. The reader treats invalid state as absent and records the fallback. Rollback is a revert; the new persisted field is optional, so the older build ignores it.

### Review focus

Please focus on the recovery boundary and whether any other component can still mint an operational interruption delivery key.

## Final checklist

Before publishing or updating the PR:

- [ ] The title names an outcome.
- [ ] Symptom, root cause, and supporting evidence are distinct.
- [ ] Scope and non-goals are explicit.
- [ ] The authoritative owner and important transitions are explained.
- [ ] Privacy, compatibility, dependency, and migration implications are addressed proportionally.
- [ ] The regression example recreates the old failure.
- [ ] Old-fail/new-pass evidence is recorded, or the absence is explicit.
- [ ] Automated, signed-app, and manual evidence are not conflated.
- [ ] Every verification claim is labeled Run, Observed, or Not run.
- [ ] Risks, rollback, and known limitations are stated.
- [ ] Relevant plan, ADR, operating docs, and agent instructions are updated.
- [ ] The diff contains no unrelated user changes.
- [ ] Draft/Ready state matches the evidence.
