# PR draft — Document the public-first update workflow

**Branch:** `agent/document-public-update-workflow` → `main`

**Compare:**
https://github.com/chocolatechipscookiecrumbles/AgentUsageMonitor/compare/main...agent/document-public-update-workflow?expand=1

**State:** Ready for review.

## Summary

- Add one canonical public-first workflow for branches, commit identity, privacy
  review, secret scanning, pull requests, releases, and confidential staging.
- Reserve history rewriting for incident response and record the GitHub Support
  purge boundary learned during publication.
- Close stale publication checklists and route README, contributing, PR, and agent
  guidance to the ongoing workflow.

## Problem and root cause

The one-time publication documents explain how the private repository became a
sanitized public repository, but they do not define the normal update loop after
publication. Without a canonical workflow, a maintainer could continue developing
in the historical private repository and periodically promote or filter its
history, recreating divergence, identity leakage, and cached-object risk.

The publication plan and “before going public” record also still described remote
publication as pending after the repository, release, security configuration, and
GitHub Support cleanup were complete.

## Scope and non-goals

**Included:**

- public `main` as the single source of truth;
- clean-clone and repository-local noreply identity setup;
- focused feature branches, staged-patch review, proposed-commit scanning, and PR
  routing;
- the exception for genuinely confidential private staging;
- history-rewrite and cached-object incident response;
- release-boundary verification;
- final publication evidence and links from durable repository guidance.

**Not included:**

- no Swift, app behavior, signing, entitlement, bundle, credential, or data change;
- no automated hook or new GitHub Actions workflow;
- no change to repository metadata, rulesets, release assets, or security settings;
- no implementation of the documented product follow-ups.

## Design and ownership

`docs/development/public-update-workflow.md` is the canonical owner of ongoing
publication safety. `AGENTS.md` makes its public-first invariant durable;
`CONTRIBUTING.md`, README, and the evidence-rich PR guide route humans and agents
to it. The historical readiness plan and checklists retain one-time evidence while
clearly identifying themselves as complete records.

## Privacy, compatibility, and migration

Documentation only. The guide prevents private repository history, personal commit
identity, sensitive staged content, and raw scanner output from entering the public
branch graph. It changes no runtime compatibility surface and requires no user or
application-data migration.

## Regression proof

No production defect changes. The documentation regression was the absence of an
ongoing public update policy plus current-tense claims that publication remained
pending. Link/anchor validation, changed-content PII searches, a current-tree
secret scan, and review of every changed document form the narrow proof boundary.

## Verification

| Check | State | Result |
|---|---|---|
| `git diff --check` | Run | Clean |
| Lychee offline Markdown link/anchor check | Run | 512 checks evaluated; 433 successful, 79 network links excluded, 0 errors |
| Gitleaks current-tree scan with full redaction | Run | 0 findings |
| Changed-content institutional-domain, user-home-path, and personal-email search | Run | 0 matches |
| Proposed-commit identity and Gitleaks range scan | Run | 1 commit; approved noreply author/committer; 0 findings |
| Swift build and tests | Not run | Documentation-only change; no runtime claim |
| Signed-app visual acceptance | Not run | No Swift or built-app change |

## Risks, rollback, and limitations

**Risk:** A workflow that is too burdensome may be bypassed; the guide therefore
uses range scans for ordinary branches and reserves full-history audits for release
or incident boundaries.

**Rollback:** Revert the documentation commit. No runtime state or GitHub
configuration requires rollback.

**Known limitations / unrun checks:** No local hook automates the workflow, and no
CI workflow enforces it. Repository and account security settings remain an
independent defense layer.

## Documentation and review focus

Review `docs/development/public-update-workflow.md` for the public/private ownership
boundary, the exact pre-push gate, the confidential-staging exception, and the
history-rewrite incident response. Confirm that the closeout edits preserve
historical evidence while removing stale pending-state claims.
