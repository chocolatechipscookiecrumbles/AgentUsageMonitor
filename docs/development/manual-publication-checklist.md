# Manual sanitized-repository publication checklist

Use this checklist for the GitHub-only work that is intentionally not delegated to
an authenticated agent. Keep the original `agent-usage` repository private. Do not
upload scanner reports, replacement maps, Actions logs, or temporary audit files to
either repository.

## 1. Audit the original private repository

- In **Actions**, confirm whether any runs exist even though local full-history
  inspection found no committed `.github/workflows` path.
- For each run, download its logs and artifacts into a new owner-only temporary
  directory. Do not save them in the repository checkout.
- Scan that directory with the same installed Gitleaks and TruffleHog versions used
  for the Git-history audit. Record only tool/version, command, count, and
  disposition; never paste a raw finding into Git or an issue.
- Delete the temporary logs and artifacts after review.
- Do not migrate Actions runs, caches, logs, artifacts, PR refs, branches, or
  stashes to the new repository.

## 2. Inspect the published `v0.0.1` release

- Download the release archive from the original private repository.
- Record the exact archive filename and the exact `.app` name inside it. Use those
  observed names in the README and release notes.
- Record the existing SHA-256 checksum before uploading anything elsewhere:

  ```sh
  shasum -a 256 <DOWNLOADED_ARCHIVE>
  unzip -Z1 <DOWNLOADED_ARCHIVE>
  ```

- Extract the archive into a temporary directory and recheck the shipped app:

  ```sh
  codesign --verify --deep --strict --verbose=2 <EXTRACTED_APP>
  spctl --assess --type execute --verbose=4 <EXTRACTED_APP>
  xcrun stapler validate <EXTRACTED_APP>
  ```

- Confirm the archive still reports **Agent Monitor**, version `0.0.1`, build
  `266`. The Developer ID output is expected to expose the certificate holder and
  is the signed-release exception to source/history sanitization.

## 3. Create the destination as private

- Create `chocolatechipscookiecrumbles/AgentUsageMonitor` as a **private** empty
  repository. Do not initialize it with a README, license, `.gitignore`, or sample
  workflow.
- Set the description to:

  > Privacy-conscious macOS menu-bar monitor for Codex and Claude Code quota windows and local token activity.

- Add topics: `macos`, `menu-bar`, `swift`, `swiftui`, `openai-codex`,
  `claude-code`, `usage-monitor`.
- Enable Issues.
- Enable private vulnerability reporting.
- Enable Dependabot alerts and dependency-graph features that GitHub makes
  available for the repository.
- Enable secret scanning and push protection wherever the private-repository plan
  exposes those controls. Recheck them after the repository becomes public.

Do not add a Code of Conduct yet. Do not add screenshots until approved,
redistributable assets exist.

## 4. Publish only the sanitized refs

Wait for the private readiness PR to merge and for the disposable rewritten mirror
to pass its post-rewrite checks. Then push only the explicitly verified refs:

```sh
git -C <REWRITTEN_MIRROR> push <NEW_PRIVATE_REPOSITORY_URL> \
  refs/heads/main:refs/heads/main
git -C <REWRITTEN_MIRROR> push <NEW_PRIVATE_REPOSITORY_URL> \
  refs/tags/v0.0.1:refs/tags/v0.0.1
```

Do not use `--mirror` or `--all`. Verify that the destination contains one branch
(`main`) and one tag (`v0.0.1`) before continuing.

## 5. Recreate the release

- Copy the original `v0.0.1` release notes to a release attached to the rewritten
  `v0.0.1` tag.
- Upload the already verified archive without rebuilding, renaming, rezipping, or
  otherwise changing it.
- Download it again from the new private repository and confirm its SHA-256 matches
  the checksum from step 2.
- Repeat the signature, Gatekeeper, and stapler checks against the newly downloaded
  copy.

## 6. Protect `main`

- Require changes through pull requests.
- Prohibit force pushes and branch deletion.
- Do not require a status check that does not exist.
- Confirm administrators are covered by the intended rule before relying on it.

## 7. Private-candidate go/no-go

From a fresh clone of the new repository:

```sh
cd AgentUsageMonitor/CodexUsageMonitor
swift build
swift test
```

Also confirm:

- only `main` and `v0.0.1` are present;
- all commit, committer, and tagger identities use
  `chocolatechipscookiecrumbles` and the approved GitHub noreply address;
- no institutional domain, legal name, Apple Team ID, or user-specific home path
  appears in the current tree or complete history;
- GitHub detects the MIT License;
- README, acknowledgements, community files, issue form, Security page, tag, and
  release render correctly;
- the release download name and contained `.app` name match the README;
- the new repository has no inherited Actions history.

## 8. Change visibility

Only after every go/no-go item passes:

1. Open **Settings → General → Danger Zone → Change repository visibility**.
2. Change the new `AgentUsageMonitor` repository from private to public.
3. Leave the original `agent-usage` repository private.
4. In a signed-out browser, repeat the README, MIT, acknowledgements, community
   files, issue form, Security page, release download, branch, tag, and metadata
   checks.
5. Recheck secret scanning, push protection, and branch protection after the
   visibility transition.

If any identity, secret, path, ref, asset, or metadata check differs from the
private candidate, stop and return the new repository to private while the
difference is investigated.
