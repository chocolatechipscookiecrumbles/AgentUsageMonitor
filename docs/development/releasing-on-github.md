# Shipping your first macOS release on GitHub

A practical, project-specific walkthrough for cutting the first downloadable
release of **Agent Monitor** — the product formerly called Codex Usage Monitor,
renamed once it supported Claude Code as well. The bundle, target, and identifier
are still `CodexUsageMonitor` / `com.david.codex-usage-monitor`; only the
user-facing name changed. This guide teaches the *why* behind each step, not just
the commands, so you can repeat it.

> **Read this first — the Claude credential caveat.** The Claude path reuses the
> OAuth credential Claude Code stores in the user's Keychain. Anthropic's Terms
> of Service do not permit a third-party application to do that. **Decided
> 2026-07-29: publish anyway, with the caveat disclosed rather than buried** —
> it is stated in the README, in the app's Data & Privacy page, and in the
> release notes, so nobody installs it without knowing. Replacing this with a
> first-party OAuth client is the first work planned after this release; until
> then, do not remove the disclosure from any of those three places. Codex usage
> is read from the local Codex CLI app-server and carries no such caveat.

## Where this stands right now (2026-07-31)

**Agent Monitor 0.0.1 is published.** The shipping `Agent Monitor` / `0.0.1` /
build `266` app was Developer ID signed, notarized, stapled, tagged `v0.0.1`, and
published. The uploaded disk image was downloaded again after publication; the user
verified the release artifact, launched it, and observed the app working as
intended.

The earlier accepted submission remains useful historical evidence, but it was not
the shipping artifact. It reports `Codex Usage Monitor` / `1.0.0` / build `254`
and predates the rename and version change.

**A notarization ticket is bound to the exact binary that was submitted**, by its
code-directory hash. Changing `CFBundleDisplayName` or `CFBundleShortVersionString`
rewrites `Info.plist`, which changes the hash, which makes the approved ticket
inapplicable. There is no way to carry it across — the ticket is not a licence for
the project, it is a receipt for one binary.

That first approval was worth something, just not the thing it initially looked
like:

| The approval **does** prove | It **does not** give you |
|---|---|
| The Developer ID certificate and its private key work for distribution signing | A shippable artifact |
| The hardened runtime, secure timestamp, and absence of `get-task-allow` all satisfy the notary | Any standing that transfers to a rebuilt bundle |
| The nested bridge is signed correctly — the usual cause of a rejected submission | Permission to skip resubmitting |

| Prerequisite | State |
|---|---|
| Build and tests green | ✅ Final integration suite: 329 tests, 0 failures |
| Optimized release binary | ✅ `build-app.sh` builds `-c release` |
| App icon | ✅ `AppIcon.appiconset`, all ten sizes; bundle `.icns` built by `iconutil` |
| Version and build number | ✅ `0.0.1` / `266` in `Info.plist`. `254` is spent — the notary has already seen it, and Apple rejects a re-used build number |
| Product name | ✅ `Agent Monitor` in every user-visible string; identity stays `CodexUsageMonitor` |
| Seven-day reliability observation | ✅ Passed — see the caveat in [reliability Task 5](../superpowers/plans/2026-07-13-codex-reliability-hardening.md#task-5-run-and-review-the-one-week-hardening-period) |
| Claude credential disclosure | ✅ README, app Data & Privacy page, release notes |
| Release notes | ✅ Published from [`docs/release-notes/0.0.1.md`](../release-notes/0.0.1.md) |
| Project / Git remote | ⏳ Original private remote remains `chocolatechipscookiecrumbles/agent-usage`; sanitized publication targets the separate `chocolatechipscookiecrumbles/AgentUsageMonitor` repository |
| **Apple Developer membership** | ✅ Active |
| **Developer ID certificate** | ✅ Developer ID Application identity installed with its private key; certificate holder and Team ID redacted from public source |
| **Notarization of the pre-rename build** | ✅ **Accepted** — `Codex Usage Monitor` / `1.0.0` / `254`. Superseded; do not publish it |
| **Notarization of the shipping build** | ✅ **Accepted and stapled** — `Agent Monitor` / `0.0.1` / `266` |
| Git tag and GitHub Release | ✅ `v0.0.1` published |
| Uploaded artifact verification | ✅ Downloaded after publication; accepted and observed working as intended |

### Shipping-build evidence — 2026-07-31

The final release completed the Developer ID build, resource verification,
notarization, stapling, packaging, tagging, and publication sequence below. The
user then downloaded the uploaded disk image and verified the released app rather than
relying on the local build. This closes the 0.0.1 release gate. It does not
retroactively claim that every possible VoiceOver, permission-denied, long-copy, or
manufactured conditional state was exercised.

### Historical signing evidence — the pre-rename build (2026-07-29)

Kept because it is the evidence that the signing setup is sound; it describes the
**approved but superseded** bundle, not the artifact later published. Read back from
`CodexUsageMonitor/.build/CodexUsageMonitor.app`, built at 18:09:

```
Authority=Developer ID Application: [certificate holder and Team ID redacted]
Authority=Developer ID Certification Authority
Authority=Apple Root CA
TeamIdentifier=[redacted]
CodeDirectory ... flags=0x10000(runtime)
Timestamp=Jul 29, 2026 at 18:09:56
```

`codesign -d --entitlements -` returns none, so there is no `get-task-allow`.
For that superseded build, `spctl -a -vv` printed
`rejected … source=Unnotarized Developer ID`; `xcrun stapler validate` likewise
reported that no ticket was stapled. Those results describe only the historical
bundle, not the published 0.0.1 artifact.

`CodexUsageMonitor-notarize.zip` was produced at 19:28 and submitted.

### Completed first-release sequence

This is the sequence used for 0.0.1 and the baseline for future releases. Run
signing, Keychain, and Apple-service steps in your own Terminal:

```sh
cd CodexUsageMonitor

# 1. Rebuild. The bundle now reports Agent Monitor / 0.0.1 / 266.
swift test && ./Scripts/build-app.sh
./Scripts/verify-signed-app-resources.sh

# 2. Confirm the rename actually reached the bundle before spending a submission.
app=.build/CodexUsageMonitor.app
plutil -extract CFBundleDisplayName raw "$app/Contents/Info.plist"        # Agent Monitor
plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist" # 0.0.1
plutil -extract CFBundleVersion raw "$app/Contents/Info.plist"            # 266
codesign -dvv "$app" 2>&1 | grep -E "Authority=Developer ID|Timestamp|flags"

# 3. Notarize and staple.
cd .build
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-notarize.zip
xcrun notarytool submit CodexUsageMonitor-notarize.zip \
  --keychain-profile "notary-codexmon" --wait
xcrun stapler staple CodexUsageMonitor.app
xcrun stapler validate CodexUsageMonitor.app     # "The validate action worked!"
spctl -a -vv CodexUsageMonitor.app               # accepted … source=Notarized Developer ID
```

The release then followed Step 4 packaging, Step 5 tagging, Step 6 publication, and
Step 7 verification of the downloaded artifact.

**Step 2 is not ceremony.** The rename lives entirely in `Info.plist` and five
Swift strings; if the build picked up a stale plist you would notarize a bundle
still calling itself Codex Usage Monitor, and only find out after publishing.

Check on a submission at any time:

```sh
xcrun notarytool history --keychain-profile "notary-codexmon"
xcrun notarytool log <submission-id> --keychain-profile "notary-codexmon"
```

Run those in **your own Terminal**. Like `security find-identity`, they can block on
a Keychain prompt and must not be run non-interactively or by an agent.

> **Do not staple, package, or tag until the notary says `Accepted`.** A rejected
> submission usually means a missing hardened runtime (already set), a nested
> unsigned Mach-O (the script signs the bridge first), or a re-used build number —
> the log command above names the actual cause.

## The mental model: what a macOS release actually needs

Downloading a `.app` from the internet is different from running one you built
locally. macOS attaches a **quarantine** flag to anything downloaded, and
**Gatekeeper** then decides whether to let it open. There are three outcomes:

| App is… | What the user sees on first open | Effort for you |
|---|---|---|
| **Notarized** (Developer ID + Apple notary) | Opens normally after a one-time prompt | Apple Developer account ($99/yr) + notarization |
| **Signed, not notarized** | "cannot be opened because Apple cannot check it" — needs right-click → Open | Developer ID cert only |
| **Ad-hoc / unsigned** | "is damaged and can't be opened" — needs `xattr` workaround | none |

So the first real decision is **which path you can do**:

- **Path A — Notarized (recommended if you have, or will buy, an Apple Developer
  membership).** Cleanest install for others.
- **Path B — Unsigned/ad-hoc (no paid account).** Fine for yourself and a few
  technical users who don't mind a terminal command; not friendly for the public.

The current `Scripts/build-app.sh` already signs with `Developer ID Application`
**when that identity exists**, and falls back to ad-hoc otherwise — so it supports
both paths.

## Pre-flight checklist (do these before you tag anything)

1. **Green build and tests.**
   ```sh
   cd CodexUsageMonitor
   swift build
   swift test          # expect: 0 failures (316 as of 2026-07-29)
   ```
   One known flake lives here: `ClaudeUsageMonitorTests.testReconnectResumesReading`
   failed twice in roughly 25 runs because it spins on a bounded `Task.yield()`
   count. Re-run before concluding anything is broken.
2. ~~**Build a *release* binary, not debug.**~~ **Resolved 2026-07-28:**
   `build-app.sh` builds `-c release` and installs the app executable and the
   bundled bridge from `.build/release/`. Override with `BUILD_CONFIGURATION=debug`
   only for local iteration — never for a release.
3. ~~**Set the version.**~~ **Done 2026-07-30:** `0.0.1` / `266`. `254` was consumed
   by the pre-rename submission and cannot be reused. Bump again for the *next*
   release. See [Step 1](#step-1--pick-and-set-the-version).
4. **Know the known gaps** so your release notes are honest:
   - ~~**No app icon yet.**~~ **Resolved 2026-07-29:** `AppIcon.appiconset`
     ships all ten macOS representations (16 through 512 at 1x and 2x), and
     `build-app.sh` builds the bundle's `AppIcon.icns` from those same PNGs with
     `iconutil` — actool's convenience `.icns` carries only four sizes, which
     left Get Info upscaling a 256. Because the app is `LSUIElement`, Finder,
     Get Info, and notification banners are the only places the icon is ever
     seen; the build fails if the `.icns` is missing.
   - ~~**The Claude bridge needs `python3`.**~~ **Resolved:** the bridge is now a
     native Swift executable bundled and signed inside the app, so a clean Mac no
     longer needs Python.
   - **`LSUIElement` app:** it lives in the menu bar with no Dock icon — tell
     users where to look after launch.
   - **The popover can outgrow a small screen.** With the Token Monitor card at
     its tallest the Codex tab measures ~915 points, against ~775 usable at
     1280×800. It does not scroll by design, so the tallest state clips on
     smaller displays; per-agent section toggles are the workaround. Deferred by
     direction — say so in the notes rather than letting a user discover it.
   - **GitHub Copilot is absent**, not broken: no personal-quota API has been
     verified for it.
   - **Several surfaces are implemented but not visually accepted** in a signed
     build. The board's **Verification** rows are the live list; nothing there
     blocks a release, but do not describe those as tested.

## Step 1 — Pick and set the version

macOS apps carry two version strings in `Info.plist`:

- `CFBundleShortVersionString` — the **marketing** version users see (e.g. `0.0.1`).
  Match this to your git tag.
- `CFBundleVersion` — a **monotonic build number** that must increase every time
  you notarize (Apple rejects a re-used build number). Bump it on every release.

Currently: `CFBundleShortVersionString = 0.0.1`, `CFBundleVersion = 266`.

**Set to `0.0.1` on 2026-07-29** (revised down from an earlier `1.0.0`) and
published on 2026-07-31. The version deliberately described a first distribution:
both providers and the release path were ready, but outside installation history
was new and the Claude credential architecture still carried disclosed follow-up
work. Keep `1.0.0` for a later maturity decision. The build number was derived from
the repository commit count at the time of the bump, which keeps it monotonic
without a second thing to remember — regenerate it with:

```sh
git rev-list --count HEAD
```

Bump both on every release; Apple rejects a re-used build number at
notarization. Edit them in `CodexUsageMonitor/Resources/Info.plist`, then commit:

```sh
git add CodexUsageMonitor/Resources/Info.plist
git commit -m "Release 0.0.1"
```

Use **SemVer** (`MAJOR.MINOR.PATCH`). A `0.x` version signals that the public
interface — and specifically the Claude credential path — may still change; see
the terms caveat in the release notes below.

> **Why `266` and not `255`.** `254` was submitted to the notary as
> `Codex Usage Monitor` / `1.0.0` and accepted. Apple keeps build numbers per
> bundle identifier, and the identifier did not change with the rename — so from
> the notary's point of view `254` is used, permanently. `266` is the next release
> build after the merge-readiness corrections, keeping the number monotonic without
> a second thing to remember.

## Step 2 — Build the release `.app`

The one-liner (uses the existing script, which handles bundling + signing):

```sh
cd CodexUsageMonitor
./Scripts/build-app.sh
./Scripts/verify-signed-app-resources.sh   # confirms the asset catalog + bridge are inside
```

This produces `CodexUsageMonitor/.build/CodexUsageMonitor.app`.

**The script builds an optimized binary.** As of 2026-07-28 it runs
`swift build -c release` and installs both the app executable and the bundled
Claude bridge from `.build/release/`, so no hand-patching is needed. Set
`BUILD_CONFIGURATION=debug` if you want a debug bundle for local iteration.

**What the script does, in order** — the order is the point, not an accident:

1. `swift build -c release`, then install the executable and the `Info.plist`.
2. `actool` compiles `Assets.xcassets` into `Assets.car` with `--app-icon AppIcon`.
3. `iconutil` builds `AppIcon.icns` from the appiconset PNGs, replacing actool's
   four-size version. The build fails if the result is missing or empty.
4. Sign the **nested** bridge helper, then the app. Code signing is applied
   inside-out, and notarization rejects an unsigned nested Mach-O.

Spot-check the icon after a build — a wrong or missing one is invisible in a
menu-bar app until someone opens Get Info:

```sh
app=.build/CodexUsageMonitor.app
plutil -extract CFBundleIconFile raw "$app/Contents/Info.plist"   # expect: AppIcon
mkdir -p /tmp/iconcheck && cp "$app/Contents/Resources/AppIcon.icns" /tmp/iconcheck/
iconutil -c iconset /tmp/iconcheck/AppIcon.icns
ls /tmp/iconcheck/AppIcon.iconset | wc -l                         # expect: 10
```

> **Rule of thumb:** *signing must be the last thing you do to the bundle.* Any
> change to the app's contents after signing invalidates the signature. This is
> why the script signs the nested bridge first and the app last — and why
> replacing the binary by hand after a build means re-signing.

### Confirming the bundle is notarization-ready

Apple's notary service rejects a bundle that lacks the hardened runtime, carries
the `get-task-allow` entitlement, or has no secure timestamp. Check all three
before submitting:

```sh
app=.build/CodexUsageMonitor.app
codesign -dvv "$app" 2>&1 | grep -E "flags|Authority=Developer ID|Timestamp"
codesign -d --entitlements - "$app"          # expect: no get-task-allow
spctl -a -vv "$app"                          # expect: rejected / Unnotarized Developer ID
```

A correct pre-notarization bundle prints `flags=0x10000(runtime)`, a
`Developer ID Application` authority, a `Timestamp=`, and no entitlements. The
`spctl` rejection is expected at this point — `source=Unnotarized Developer ID`
means the signature is right and notarization is the only remaining step.

### Getting the certificate (do this once, after the membership)

1. Join the [Apple Developer Program](https://developer.apple.com/programs/)
   ($99/yr). Approval is not always instant.
2. In **Xcode → Settings → Accounts**, add your Apple ID, select the team, then
   **Manage Certificates… → + → Developer ID Application**. Xcode creates the
   certificate and installs it with its private key in your login keychain.
   (The web equivalent is Certificates, Identifiers & Profiles → Certificates →
   **+** → Developer ID Application, which requires uploading a CSR from
   Keychain Access.)
3. Note the team ID — it is the parenthesized code in the identity name and the
   value `notarytool` wants as `--team-id`.

The certificate and its private key must be in the **same keychain** and both
present. A certificate restored without its key signs nothing.

### Choosing the signing identity

Check what you have:

```sh
security find-identity -v -p codesigning
```

> Run that in **your own Terminal**, interactively. It can block on a Keychain
> access prompt — it timed out at two minutes when run non-interactively on
> 2026-07-29 — so never put it in a script or let an agent run it for you. For
> the same reason `build-app.sh` attempts the real signature directly instead of
> probing for an identity first.

- If you see a **`Developer ID Application: … (<APPLE_TEAM_ID>)`** line → Path A. The script
  picks it up automatically, or set it explicitly:
  ```sh
  CODESIGN_IDENTITY="Developer ID Application: Project maintainer (<APPLE_TEAM_ID>)" ./Scripts/build-app.sh
  ```
  Then re-run the notarization-readiness checks above. On the release machine,
  confirm that the selected identity exists and that the current `.build` bundle
  has the hardened runtime and a secure timestamp; the public documentation does
  not record the certificate holder or Team ID.
- If you see nothing usable → Path B (ad-hoc). The script warns and continues; skip
  the notarization step and read [Path B](#path-b--no-paid-account-unsignedad-hoc).

## Step 3 (Path A) — Notarize and staple

Notarization = Apple scans your signed app and issues a ticket; **stapling**
attaches that ticket so it works offline.

> **Status 2026-07-30:** the credential profile is stored and the pre-rename
> `1.0.0` / `254` build was **accepted**. The one-time setup below is done. The
> submit, staple, and validate commands are what you run against the rebuilt
> `Agent Monitor` / `0.0.1` / `266` bundle — the accepted ticket does not carry
> over to it.

**One-time setup:** store an app-specific password (make one at
appleid.apple.com → Sign-In & Security → App-Specific Passwords) in the keychain:

```sh
xcrun notarytool store-credentials "notary-codexmon" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "abcd-efgh-ijkl-mnop"     # the app-specific password
```

**Every release:** notarization needs a zip (or dmg) of the `.app`:

```sh
cd CodexUsageMonitor/.build
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-notarize.zip

xcrun notarytool submit CodexUsageMonitor-notarize.zip \
  --keychain-profile "notary-codexmon" --wait

# On "status: Accepted", staple the ticket onto the .app:
xcrun stapler staple CodexUsageMonitor.app
xcrun stapler validate CodexUsageMonitor.app      # expect "The validate action worked!"
```

If it says **Invalid**, run
`xcrun notarytool log <submission-id> --keychain-profile "notary-codexmon"` — the
usual causes are a missing hardened runtime (`--options runtime`, already set) or a
nested unsigned binary.

## Step 4 — Package the download

The published 0.0.1 artifact is `AgentUsageMonitor-0.0.1.dmg`, containing
`AgentUsageMonitor.app`. The build script still produces the internal compatibility
name `.build/CodexUsageMonitor.app`; copy that signed bundle to the distribution
name in a staging directory before creating the disk image. The exact historical
DMG command was not retained; this is the repeatable packaging baseline:

```sh
cd CodexUsageMonitor/.build
dmg_stage=$(mktemp -d)
ditto CodexUsageMonitor.app "$dmg_stage/AgentUsageMonitor.app"
ln -s /Applications "$dmg_stage/Applications"
codesign --verify --deep --strict --verbose=2 "$dmg_stage/AgentUsageMonitor.app"
hdiutil create -volname AgentUsageMonitor \
  -srcfolder "$dmg_stage" \
  -ov -format UDZO AgentUsageMonitor-0.0.1.dmg
```

Renaming the outer bundle directory does not modify its signed contents. Verify the
copied app before packaging, then verify the mounted copy again after download.

## Step 5 — Tag the release

The tag is the immutable marker the GitHub Release is built from. Match it to
`CFBundleShortVersionString`, prefixed with `v`:

```sh
git tag -a v0.0.1 -m "Agent Monitor 0.0.1"
git push origin v0.0.1
```

(Tag the commit that produced the binary you're shipping — usually `main` after the
PR merged.)

## Step 6 — Create the GitHub Release

### Option 1 — `gh` CLI (fastest, once authenticated)

Authenticate in the maintainer's terminal and target the sanitized repository
explicitly:

```sh
gh auth login          # choose GitHub.com → HTTPS → follow the browser prompt
```

Then create the release and attach the disk image:

```sh
gh release create v0.0.1 "CodexUsageMonitor/.build/AgentUsageMonitor-0.0.1.dmg" \
  --repo chocolatechipscookiecrumbles/AgentUsageMonitor \
  --title "Agent Monitor 0.0.1" \
  --notes-file docs/release-notes/0.0.1.md
```

### Option 2 — Web UI

1. Go to **Releases → Draft a new release** in the repo.
2. Choose the tag `v0.0.1` (or create it there).
3. Title + notes (paste the notes below).
4. **Attach binaries** → drop in `AgentUsageMonitor-0.0.1.dmg`.
5. **Publish.** Ticking **pre-release** is a reasonable call at `0.0.1`: it is a
   first distribution of a build nobody outside this machine has run.

### The release notes

Already written: **[`docs/release-notes/0.0.1.md`](../release-notes/0.0.1.md)**.
Read it before publishing and adjust anything that has since changed. It is what
`--notes-file` points at in the commands above.

It deliberately leads with install steps and the Claude credential caveat, then
lists what the app does and its known limitations. Keep that shape for future
releases: a user deciding whether to install should hit the caveat before the
feature list, not after it.

If you ship **Path B** (ad-hoc, unsigned), add the quarantine workaround to the
Install section — the current text omits it because Path A needs no such step:

```markdown
   - *Unsigned build:* if macOS says the app is damaged, run
     `xattr -dr com.apple.quarantine /Applications/AgentUsageMonitor.app`
```

## Step 7 — Verify the download like a stranger would

Don't trust the app you built; trust the artifact you uploaded. Download
`AgentUsageMonitor-0.0.1.dmg` from the Release page to another folder (or another
Mac), mount it, and copy `AgentUsageMonitor.app` to a temporary folder. Then:

```sh
# Simulate a fresh download's quarantine flag, then check Gatekeeper's verdict:
xattr -w com.apple.quarantine "0081;00000000;Safari;" <TEMP_DIRECTORY>/AgentUsageMonitor.app
spctl -a -vvv <TEMP_DIRECTORY>/AgentUsageMonitor.app
```

- Path A (notarized): `spctl` prints **`accepted … source=Notarized Developer ID`**.
- Path B: `spctl` **rejects** it — expected; users need the right-click-Open or
  `xattr` step from the notes.

## Path B — no paid account (unsigned/ad-hoc)

You can still ship, with a worse first-run experience:

1. Build normally; the script falls back to ad-hoc and warns you.
2. Skip notarization and stapling entirely.
3. Zip and release as above. Tick **pre-release** on the GitHub Release — an
   unsigned build is not something to hand the public unqualified, quite apart
   from what the version number says.
4. **Be explicit in the notes** that macOS will say the app "is damaged" or
   "cannot be opened," and give users the fix:
   ```sh
   xattr -dr com.apple.quarantine /Applications/CodexUsageMonitor.app
   ```
   (This clears the quarantine flag they'd otherwise be blocked by.)

This is fine for yourself and technical friends; it is not a good public
distribution story. If the app is worth publishing broadly, the $99/yr Developer
Program + Path A is the real fix.

**One caution specific to this app.** Ad-hoc signatures have no certificate, so
the designated requirement is pinned to the binary's cdhash and changes on every
build. Keychain "Always Allow" grants are keyed to that requirement, so the
Claude credential prompt returns after each rebuild. That is the defect
`build-app.sh` documents at its signing step — it is a real usability
difference between the two paths, not just a Gatekeeper one.

## Quick reference — the whole flow (Path A)

Icon and notes are in place and `CFBundleShortVersionString` is `0.0.1`, so from a
working Developer ID certificate this is the whole thing:

```sh
# 0. set CFBundleVersion to a number never notarized before
git rev-list --count HEAD    # write the result into Resources/Info.plist
# 1. build + sign (script handles release config, assets, icns, nested signing)
cd CodexUsageMonitor && swift test && ./Scripts/build-app.sh
./Scripts/verify-signed-app-resources.sh
# 2. notarize + staple
cd .build && ditto -c -k --keepParent CodexUsageMonitor.app notarize.zip
xcrun notarytool submit notarize.zip --keychain-profile "notary-codexmon" --wait
xcrun stapler staple CodexUsageMonitor.app
xcrun stapler validate CodexUsageMonitor.app
# 3. package
dmg_stage=$(mktemp -d)
ditto CodexUsageMonitor.app "$dmg_stage/AgentUsageMonitor.app"
ln -s /Applications "$dmg_stage/Applications"
codesign --verify --deep --strict --verbose=2 "$dmg_stage/AgentUsageMonitor.app"
hdiutil create -volname AgentUsageMonitor -srcfolder "$dmg_stage" \
  -ov -format UDZO AgentUsageMonitor-0.0.1.dmg
# 4. tag
cd ../.. && git tag -a v0.0.1 -m "Agent Monitor 0.0.1" && git push origin v0.0.1
# 5. release
gh release create v0.0.1 CodexUsageMonitor/.build/AgentUsageMonitor-0.0.1.dmg \
  --repo chocolatechipscookiecrumbles/AgentUsageMonitor \
  --title "Agent Monitor 0.0.1" --notes-file docs/release-notes/0.0.1.md
```

For a **later** release, add a step 0: bump `CFBundleShortVersionString` and set
`CFBundleVersion` to `git rev-list --count HEAD`, then commit.

## Where this can grow later

- **Automate it** with a GitHub Actions workflow triggered on `v*` tags (build,
  sign with secrets, notarize, upload). Do this once the manual flow is boring.
- **Auto-update** with [Sparkle](https://sparkle-project.org/) + an appcast, so
  users get new versions without re-downloading.
- **A `.dmg`** with a styled drag-to-Applications window for nicer first impressions.
- **A first-party Claude OAuth client**, which is what retires the terms caveat
  at the top of this file. Planned as the first post-release work.
- **One executable in the app bundle.** In 0.0.1 the Claude status-line bridge is
  a separately built and signed nested executable. [Product Follow-up 10](../product/follow-ups.md#10-consolidate-the-claude-usage-bridge-into-the-app-executable)
  tracks moving its entry point into a non-UI mode of the main app executable so
  future releases have one executable binary and no nested-helper signing step.
