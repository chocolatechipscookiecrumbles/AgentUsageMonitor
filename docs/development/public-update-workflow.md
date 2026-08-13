# Public Update Workflow

AgentUsageMonitor's public repository is the project's single source of truth.
Start every change from the public `main` branch, publish only reviewed feature
branches, and merge through a pull request. The original private repository is a
historical archive; never merge, mirror, or promote its history into this
repository.

This guide is a preventive publication gate. It is not a reason to rewrite Git
history before ordinary pushes.

## One-time local setup

Clone the public repository into a clean working directory. Do not reuse a clone
whose history came from the private archive.

```sh
git clone https://github.com/chocolatechipscookiecrumbles/AgentUsageMonitor.git
cd AgentUsageMonitor

git config --local user.name "chocolatechipscookiecrumbles"
git config --local user.email \
  "chocolatechipscookiecrumbles@users.noreply.github.com"
git config --local user.useConfigOnly true
git config --local push.default simple
```

Confirm the repository and identity before the first change:

```sh
git remote -v
git config --local user.name
git config --local user.email
```

Maintainers should also enable both GitHub account settings under
**Settings → Emails**:

- **Keep my email addresses private**
- **Block command line pushes that expose my email**

Repository secret scanning and push protection are a second line of defense, not
a substitute for reviewing commits before they leave the computer.

## Start every change from public `main`

```sh
git switch main
git pull --ff-only
git switch -c fix/short-description
```

Use a short-lived branch for one approved outcome. A branch is public as soon as
it is pushed, including every commit that is later amended, rebased, or deleted.
Do not push temporary credentials, private paths, personal identifiers, account
data, raw diagnostics, private prompts or responses, signing material, or scanner
reports with the intention of cleaning them up later.

When work needs isolation from another local change, create a worktree from
current public `main`; do not switch back to the private archive as a staging
area.

## Review the exact public patch

Before committing:

```sh
git status --short
git diff --check
git diff
```

Stage explicit paths rather than sweeping the working tree:

```sh
git add path/to/file
git diff --cached --check
git diff --cached
```

Review the staged patch for:

- credentials, tokens, authorization URLs, cookies, and session records;
- personal or institutional email addresses and names;
- Apple Team IDs, certificate-holder details, and signing output;
- user-specific absolute paths or private repository URLs;
- prompts, responses, account identifiers, or private source code;
- generated reports, logs, archives, and local build products.

Keep any private pattern list used for PII scanning outside the repository. Never
commit the pattern list or raw scan output.

## Verify the commit before pushing

Create focused commits, fetch current public refs, then inspect the author and
committer identity of every proposed commit:

```sh
git commit -m "Describe the outcome"
git fetch origin --prune

git log --reverse origin/main..HEAD \
  --format='%h | %an <%ae> | %cn <%ce> | %s'
```

Every author and committer must use the approved GitHub handle and GitHub-provided
noreply address. Correct a bad local commit before pushing; do not rely on a later
history rewrite.

Scan only the commits being proposed:

```sh
gitleaks git . \
  --log-opts='origin/main..HEAD' \
  --redact=100
```

Treat every new finding as a stop condition until it is reviewed. Do not bypass
GitHub push protection merely to complete a push.

Run verification proportional to the change. Documentation-only changes require
link, anchor, and structure checks. Production Swift changes require the build,
focused regression evidence, and any signed-app visual or interaction acceptance
specified by `AGENTS.md` and the active implementation plan.

The baseline Swift checks are:

```sh
cd CodexUsageMonitor
swift build
swift test
cd ..
```

## Push a feature branch and open a pull request

```sh
git push -u origin fix/short-description
```

Open a pull request against current `main` using
`.github/pull_request_template.md` and the
[evidence-rich PR contract](evidence-rich-pull-requests.md). Separate evidence
that was run or directly observed from checks that were not run. Never claim that
compilation proves native macOS presentation or interaction.

The `main` ruleset is authoritative. Do not bypass its pull-request, force-push,
or deletion protections. If a required approval cannot be satisfied by a solo
maintainer, change the ruleset deliberately rather than bypassing or disabling
unrelated protections.

For stacked pull requests, keep every base moving toward `main`. Follow
[the stacked-branch procedure](evidence-rich-pull-requests.md#keep-stacked-pull-request-bases-moving-in-the-same-direction)
before merging or deleting any layer.

## After merge

```sh
git switch main
git pull --ff-only
git branch -d fix/short-description
git push origin --delete fix/short-description
```

Confirm the merged result is present on `main` before deleting a stacked or
squash-merged branch. The evidence-rich PR guide documents the required ancestry
and patch-equivalence checks.

Create release branches, tags, release notes, and signed artifacts only from the
public repository's reviewed `main`. Follow
[Releasing on GitHub](releasing-on-github.md); never promote release history from
the private archive.

## Confidential work is an exception

Use private staging only when the work itself cannot be public before review. A
private staging repository must start from sanitized public `main`, use the same
noreply identity, and remain separate from the historical private archive.

Before publication, apply or squash the reviewed patch onto a fresh branch based
on public `main`, inspect the newly created commit metadata, and repeat every
privacy, secret, build, and PR check in this guide. Never merge the private
staging repository's branch graph into the public repository.

## History rewriting is incident response

Do not run `git-filter-repo`, force-push rewritten history, or clone-and-promote
from a private repository as part of normal iteration. Those operations change
commit identities, complicate collaboration, and can leave old GitHub objects
reachable through cached commit URLs.

If sensitive data is pushed:

1. Stop further pushes and record the exact affected refs and commits without
   copying the sensitive value into an issue or PR.
2. Revoke or rotate real credentials immediately.
3. Temporarily make the repository private when the exposure warrants it.
4. Remove the data from every reachable branch and tag using a reviewed incident
   plan.
5. Re-run full-history secret and PII checks.
6. Contact GitHub Support when an unreferenced commit or cached view remains
   publicly retrievable by SHA.
7. Reopen the repository only after credential-free verification proves that the
   affected object no longer resolves and all intended refs remain intact.

Record only scanner versions, commands, counts, fingerprints, and dispositions.
Keep raw findings and replacement maps outside Git.

## Release-boundary audit

Normal feature pushes scan the proposed range. Before a release, repository
transfer, or visibility change, repeat the broader boundary:

- verify every branch, tag, author, committer, and tagger identity;
- run Gitleaks and TruffleHog against complete reachable history;
- search current and historical text for private identifiers and absolute paths;
- run `git fsck --full` and inspect unexpectedly large objects;
- verify documentation links and anchors;
- build and test from a fresh clone;
- download the published artifact and recheck its checksum, signature,
  Gatekeeper assessment, and notarization ticket;
- inspect the repository without credentials and confirm security controls and
  branch rules remain active.

History-wide rewriting should remain rare. A clean public-first branch workflow
keeps ordinary updates ordinary.
