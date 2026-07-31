# PR draft — Prepare source for sanitized public repository

Compare:
historical private-repository comparison (branch not published)

## Summary

- Add the MIT License and GitHub-native security, contribution, and privacy-safe
  bug-reporting guidance.
- Sanitize current documentation, move the maintainer operating notes to
  `docs/development/operating-notes.md`, and make the future public-repository
  naming and licensing boundaries explicit.
- Record the separate full-history rewrite/publication gate and the deferred
  Diagnostics affiliation notice without changing Swift or the signed app.

## Problem and root cause

The private repository contains source-license ambiguity, personal signing/path
details, Git metadata that uses an institutional identity, and operational
documentation shaped around a private working repository. Publishing that
repository directly would expose its old review/Actions surface and leave source
licensing and community expectations unclear.

This branch prepares the current tree only. Complete Git-history rewriting and
publication target a new private `AgentUsageMonitor` repository after this change
is reviewed and merged.

## Scope and non-goals

**Included:**

- MIT licensing and clarification of its boundary;
- current-tree documentation and identity sanitization;
- `how-to.md` → `docs/development/operating-notes.md`, with current references
  repaired;
- `SECURITY.md`, `CONTRIBUTING.md`, issue form, and blank-issue policy;
- public-readiness, manual-publication, and deferred Diagnostics-disclaimer plans;
- truthful verification labels and correction of broken historical local links.

**Not included:**

- no Swift, bundle, signing, entitlement, Team ID, application identifier, or
  release-binary change;
- no Git-history rewrite in the working repository;
- no GitHub Actions/release audit, remote push, new repository, visibility change,
  Code of Conduct, or screenshots;
- no implementation of the Diagnostics affiliation notice.

## Design and ownership

The original `agent-usage` repository remains the private owner of its PRs,
Actions, branches, stashes, and audit history. A disposable mirror will own the
one-time history rewrite; the new public-facing repository receives only sanitized
`main` and `v0.0.1`.

## Privacy, compatibility, and migration

This change adds no data read, process, permission, credential, network request, or
saved-state migration. Personal legal-name, institutional-domain, Team-ID, and
user-home-path strings are removed from the current public candidate. The already
signed release is explicitly exempt because its Developer ID signature inherently
identifies the certificate holder.

Compatibility names such as the bundle identifier, target, source directory, and
Application Support directory remain unchanged.

## Regression proof

No product defect or Swift behavior changes, so no regression test is added.
The relevant regression boundaries are documentation integrity and privacy:
targeted current-tree searches return no prohibited identity/path values, and all
local Markdown/HTML paths and anchors resolve.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` | Run | Exit 0 |
| `swift test` | Run | 329 tests, 1 skipped, 0 failures |
| `git diff --check` | Run | Exit 0 |
| Lychee 0.24.2 offline local-link/anchor check | Run | 532 checked; 430 successful, 102 network links excluded, 0 errors |
| Gitleaks 8.30.1 edited-tree scan | Run | 0 candidates |
| TruffleHog 3.96.0 edited-tree scan | Run | 0 candidates |
| Gitleaks 8.30.1 pre-rewrite full-history scan | Run | 1 redacted instructional shell-variable placeholder; no credential |
| TruffleHog 3.96.0 pre-rewrite full-history scan | Run | 0 candidates |
| Targeted pre-rewrite PII/URL inventory | Run | Metadata, blobs, messages, and annotated tag inventoried with counts only; rewrite required |
| Full-history workflow-path inspection | Run | No `.github/workflows` path was ever committed |
| Current-tree prohibited identity/path searches | Run | 0 matches |
| Published artifact and contained `.app` name | Observed | Maintainer confirmed `AgentUsageMonitor-0.0.1.dmg` contains `AgentUsageMonitor.app` |
| Private Actions logs/artifacts audit | Not run | Authenticated GitHub work remains manual |
| Signed-app visual checks | Not run | No Swift or built-app change |

## Risks, rollback, and limitations

**Risk:** Publishing before the history rewrite or before reconciling the real
release asset name could expose historical identity data or give incorrect install
instructions.

**Rollback:** Revert this documentation-only commit in the original private
repository. Do not publish the rewritten candidate.

**Known limitations / unrun checks:** The authenticated Actions audit, artifact
checksum/signature recheck, final history rewrite, post-rewrite scans, new private
repository configuration, release migration, and signed-out browser checks remain
gated after this PR.

## Documentation and review focus

Review the licensing boundary, the explicit redaction labels in historical signing
evidence, the operating-notes move, community privacy copy, and the division
between the original private repository and the new rewritten public candidate.
The active evidence and remaining gates are indexed from
`docs/superpowers/plans/2026-07-31-sanitized-public-repository-readiness.md`.
