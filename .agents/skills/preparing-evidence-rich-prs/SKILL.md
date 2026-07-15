---
name: preparing-evidence-rich-prs
description: Use when preparing, reviewing, or updating a pull request for this repository, especially after behavior changes, bug fixes, native macOS UI work, parser changes, dependency changes, or incomplete verification.
---

# Preparing Evidence-Rich PRs

Make the PR a proportional, verifiable argument for the change. Never turn an unrun check into a claim.

## Workflow

1. Read the nearest `AGENTS.md`, the active implementation plan, `../../../docs/development/evidence-rich-pull-requests.md`, and `../../../.github/pull_request_template.md`.
2. Inspect the branch, status, and full diff. Preserve user changes. If unrelated work is present, use an isolated worktree or clean checkout for the PR branch.
3. State the observable problem, actual root cause, scope, and non-goals. Call an unconfirmed cause a hypothesis and keep the PR Draft.
4. Name the authoritative owner, important transitions, compatibility boundary, privacy impact, and rollback. Use “Not applicable” instead of inventing detail.
5. Explain the regression proof: the old behavior reproduced, the focused test failing for the expected reason on pre-fix code, and the same test passing on fixed code.
6. Separate evidence as **Run**, **Observed**, or **Not run**. Use **Run** only when the exact command and inspected result are available; a reported pass without them is incomplete evidence. Compilation does not prove native macOS presentation or interaction.
7. Update plans, ADRs, operating docs, and agent instructions when their facts changed.
8. Fill the PR template with verified facts only. Keep routine sections to a short paragraph or “Not applicable”; expand only where the change's risk warrants it. Choose Draft or Ready from the repository guide, not optimism.
9. After feedback, verify the concern, make focused follow-up commits, rerun affected checks, and update the PR's scope, risks, and evidence.

## Evidence by Change Type

| Change | Extra evidence |
|---|---|
| Parser or collector | Sanitized fixtures; malformed/partial input; privacy sentinel; old-fail/new-pass |
| Notification or scheduling | Full episode through retries, relaunch, recovery, and a new episode |
| Settings or native menu | Signed `.app`; required real-window/menu acceptance; unobserved states named |
| Dependency, auth, or local data | Provenance, licenses, transitive risk, permissions, failure UX, update and rollback path |
| Documentation only | Link and structure checks; no invented runtime certification |

## Regression Constraint

If repository instructions disallow automated application tests, do not silently add or run them. Document the smallest missing test, write a manual acceptance matrix, label it manual rather than automated regression coverage, and keep the PR Draft if that missing protection blocks the agreed bar.

## Completion Gate

The branch contains only intended files; the PR names outcome, cause, ownership, regression proof, evidence, risk, rollback, limitations, and review focus in proportion to the change; all required documents match actual behavior.
