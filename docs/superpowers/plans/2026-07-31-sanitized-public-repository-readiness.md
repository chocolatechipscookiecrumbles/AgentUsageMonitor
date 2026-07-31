# Sanitized public repository readiness plan

**Status:** In progress on a private feature branch. Publication and visibility
remain gated on full-history scanning, rewrite verification, and the maintainer's
final go/no-go decision.

## Objective

Prepare the private source tree for an MIT-licensed public repository, then publish
only a sanitized rewritten `main` and `v0.0.1` to
`chocolatechipscookiecrumbles/AgentUsageMonitor`. The original repository remains
private and retains its pull requests, Actions, branches, stashes, and audit trail.

## Current-tree readiness

- [x] Add the MIT licence with the maintainer's GitHub handle.
- [x] Replace source-licensing restrictions with MIT wording while retaining
  provider-policy risk disclosures.
- [x] Move the former root operating file to
  `docs/development/operating-notes.md` and update current references.
- [x] Add security, contribution, and privacy-safe bug-report guidance.
- [x] Sanitize current documentation paths and signing examples.
- [x] Record the signed Data & Privacy disclosure as rechecked and unchanged.
- [x] Add a separate future plan for the Diagnostics affiliation disclaimer; make
  no Swift change in this work.
- [ ] Reconcile the README download/archive and contained-app names from the actual
  published release asset. Do not infer them from old prose.
- [x] Complete Markdown link and anchor validation: Lychee 0.24.2 checked 532
  Markdown/HTML links offline with anchor validation; 430 checks succeeded, 102
  network links were excluded by offline mode, and zero local links or anchors
  failed.

## History and publication gate

- [ ] The maintainer will audit private Actions runs, logs, and artifacts manually;
  no GitHub authentication is authorized for this execution. Local full-history
  inspection confirms no `.github/workflows` path was ever committed.
- [x] Run Gitleaks and TruffleHog against an owner-only disposable mirror before
  rewriting. Gitleaks 8.30.1 reported one fully redacted `curl-auth-header`
  candidate in the deleted historical `docs/claude-usage-verification.md`; review
  confirmed it is the documented `$CLAUDE_ACCESS_TOKEN` shell-variable
  placeholder. TruffleHog 3.96.0, with verification and auto-update disabled,
  reported zero candidates. Raw reports remain mode `0600` outside the repository.
- [ ] Rewrite author, committer, tagger, message, path, identity, and canonical
  repository-URL history in the disposable mirror.
- [ ] Re-run secret, PII, object-size, and repository-integrity checks against the
  rewritten candidate.
- [ ] Create a new private `AgentUsageMonitor` repository and push only rewritten
  `main` and rewritten `v0.0.1`.
- [ ] Migrate the verified release asset and release notes without changing its
  checksum, then recheck signature, notarization, Gatekeeper, archive name, and
  contained app name.
- [ ] Configure repository metadata, Issues, private vulnerability reporting,
  security features, and `main` protection using only checks that exist.
- [ ] Verify the private candidate in a signed-out browser. The maintainer alone
  changes visibility to public after the final go/no-go.

## Evidence policy

No secret-scanner raw report, replacement map, sensitive value, Actions log, or
artifact audit material may enter Git. Claims about unobserved visual,
accessibility, permission, or conditional states remain explicitly unverified.

The edited current tree was also scanned separately before commit: Gitleaks 8.30.1
reported zero candidates, and TruffleHog 3.96.0 reported zero candidates from an
owner-only snapshot excluding Git metadata and build products.

GitHub-only work follows the
[manual publication checklist](../../development/manual-publication-checklist.md).

Current-tree verification on 2026-07-31: `swift build` exited zero; `swift test`
executed 329 tests with 1 skipped and 0 failures; `git diff --check` exited zero.
Signed-app visual checks were not rerun because this change does not modify Swift
or the built app.
