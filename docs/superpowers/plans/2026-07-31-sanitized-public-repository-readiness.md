# Sanitized public repository readiness plan

**Status:** Complete. The sanitized repository and release are public, the original
repository remains private, and the final credential-free and fresh-clone checks
passed after GitHub Support purged the discarded initialization commit.

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
- [x] Reconcile the README and release notes to the maintainer-observed published
  asset: `AgentUsageMonitor-0.0.1.dmg`, containing `AgentUsageMonitor.app`.
- [x] Complete Markdown link and anchor validation: Lychee 0.24.2 checked 532
  Markdown/HTML links offline with anchor validation; 430 checks succeeded, 102
  network links were excluded by offline mode, and zero local links or anchors
  failed.

## History and publication gate

- [x] Audit private Actions runs, logs, and artifacts. GitHub displayed the
  first-time Actions setup page with no workflow sidebar or run list; the audit
  found zero runs, logs, or artifacts. Local full-history inspection also confirms
  no `.github/workflows` path was ever committed.
- [x] Run Gitleaks and TruffleHog against an owner-only disposable mirror before
  rewriting. Gitleaks 8.30.1 reported one fully redacted `curl-auth-header`
  candidate in the deleted historical `docs/claude-usage-verification.md`; review
  confirmed it is the documented `$CLAUDE_ACCESS_TOKEN` shell-variable
  placeholder. TruffleHog 3.96.0, with verification and auto-update disabled,
  reported zero candidates. Raw reports remain mode `0600` outside the repository.
- [x] Inventory targeted rewrite material without recording raw values. The
  pre-rewrite mirror contains 525 institutional-email author/committer metadata
  fields; 59 legal-name, 185 Team-ID, 1,225 user-home-path, and 193 canonical
  old-repository-URL blob commit/file matches; one Team-ID commit-message line;
  and one annotated tag whose tagger/message require rewriting. The institutional
  domain does not appear in historical text blobs.
- [x] Rewrite author, committer, tagger, message, path, identity, and canonical
  repository-URL history in the disposable mirror.
- [x] Re-run secret, PII, object-size, and repository-integrity checks against the
  rewritten candidate.
- [x] Create a new private `AgentUsageMonitor` repository and push only rewritten
  `main` and rewritten `v0.0.1`.
- [x] Migrate the verified release asset and release notes without changing its
  checksum, then recheck signature, notarization, Gatekeeper, disk-image name, and
  contained app name.
- [x] Configure repository metadata, Issues, private vulnerability reporting,
  security features, and `main` protection using only checks that exist.
- [x] Verify the private candidate, change visibility to public, and repeat the
  required checks without credentials. GitHub Support subsequently purged the
  discarded initialization commit after its cached SHA view remained reachable;
  the public page now returns `404` and the API no longer resolves the object.

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

Post-rewrite verification on 2026-07-31:

- 281 source commits were rewritten before this audit record was appended.
  The candidate contains only `main` and the rewritten annotated `v0.0.1` tag.
- Every author, committer, and tagger identity is
  `chocolatechipscookiecrumbles` with the approved GitHub noreply address.
- Full-history searches return zero targeted identity, institutional-domain,
  Team-ID, user-home-path, old-repository-URL, or stale compare-link matches in
  blobs, commit messages, tag messages, and Git metadata.
- Thirteen private/deleted-branch compare links in the current tree became labeled
  historical text. Apart from those 13 one-line replacements and this audit
  record, the rewritten current tree matches the merged private `main`.
- Gitleaks 8.30.1 reports the same single instructional shell-variable placeholder
  as the pre-rewrite scan; TruffleHog 3.96.0 reports zero candidates. The Gitleaks
  item remains a documented false positive, not a credential.
- `git fsck --full` exits zero with no dangling objects after garbage collection,
  and no reachable blob exceeds 5 MiB.
- A fresh clone passes `swift build`, 329 tests with 1 skipped and 0 failures,
  `git diff --check`, and the offline local-link/anchor check with zero errors.

Post-public closeout on 2026-07-31:

- The original `chocolatechipscookiecrumbles/agent-usage` repository remains
  private. `chocolatechipscookiecrumbles/AgentUsageMonitor` is public with only
  `main` and the annotated `v0.0.1` tag.
- Credential-free requests return `200` for the repository, README, MIT licence,
  Security and Contributing pages, issue chooser, release, release download,
  branches, and tags. The README contains the project acknowledgements.
- The published `AgentUsageMonitor-0.0.1.dmg` retains SHA-256
  `1a5625e906e6ab1f747a9b124ca30399d27ec8857622d5afafcc574bd0c82364`,
  contains `AgentUsageMonitor.app`, and passed disk-image, Developer ID,
  Gatekeeper, and notarization-ticket verification.
- Private vulnerability reporting, Dependabot security updates, secret scanning,
  and push protection are enabled. Secret scanning and Dependabot reported zero
  alerts. The active `main` ruleset requires pull requests and prohibits deletion
  and non-fast-forward updates.
- GitHub Support ran server-side cleanup for the unreferenced initialization
  commit. Its credential-free commit page returns `404`; its API lookup no longer
  resolves. The intended public refs and release were unchanged.
- A final fresh public clone contains 282 reachable commits, all authors,
  committers, and the tagger use the approved GitHub noreply identity, Gitleaks
  reports only the reviewed instructional shell-variable placeholder, TruffleHog
  reports zero candidates, and the Markdown link/anchor check reports zero errors.
- The same fresh clone passes `swift build` and 329 tests with 1 skipped and zero
  failures. Existing compiler warnings remain future maintenance rather than a
  publication blocker.
- Ongoing changes now follow the
  [public update workflow](../../development/public-update-workflow.md). The public
  repository is the single source of truth; history rewriting is reserved for
  incident response rather than routine iteration.
