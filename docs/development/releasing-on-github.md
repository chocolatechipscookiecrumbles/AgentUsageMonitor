# Shipping your first macOS release on GitHub

A practical, project-specific walkthrough for cutting the first downloadable
release of **Codex Usage Monitor** (`com.david.codex-usage-monitor`). It teaches
the *why* behind each step, not just the commands, so you can repeat it.

> **Read this first — the Claude credential caveat.** The Claude path reuses the
> OAuth credential Claude Code stores in the user's Keychain. Anthropic's Terms
> of Service do not permit a third-party application to do that. **Decided
> 2026-07-29: publish anyway, with the caveat disclosed rather than buried** —
> it is stated in the README, in the app's Data & Privacy page, and in the
> release notes, so nobody installs it without knowing. Replacing this with a
> first-party OAuth client is the first work planned after this release; until
> then, do not remove the disclosure from any of those three places. Codex usage
> is read from the local Codex CLI app-server and carries no such caveat.

## Where this stands right now (2026-07-29)

Everything that does not require an Apple Developer account is done. Resume at
**Step 3**.

| Prerequisite | State |
|---|---|
| Build and tests green | ✅ 316 tests, 0 failures |
| Optimized release binary | ✅ `build-app.sh` builds `-c release` |
| App icon | ✅ `AppIcon.appiconset`, all ten sizes; bundle `.icns` built by `iconutil` |
| Version and build number | ✅ `1.0.0` / `254` in `Info.plist` |
| Seven-day reliability observation | ✅ Passed — see the caveat in [reliability Task 5](../superpowers/plans/2026-07-13-codex-reliability-hardening.md#task-5-run-and-review-the-one-week-hardening-period) |
| Claude credential disclosure | ✅ README, app Data & Privacy page, release notes |
| Release notes | ✅ Drafted at [`docs/release-notes/1.0.0.md`](../release-notes/1.0.0.md) |
| Git remote | ✅ `origin` → `chocolatechipscookiecrumbles/agent-usage` |
| **Apple Developer membership** | ❌ **Not yet — this is the blocker** |
| **Developer ID certificate** | ❌ Follows from the membership |
| **Notarization** | ❌ Never run |
| `gh` CLI authenticated | ❌ `gh auth login` still needed (or use the web UI) |

So the remaining sequence is: buy the membership → create and install a
**Developer ID Application** certificate → rebuild so the app is signed with it
→ Step 3 (notarize + staple) → Steps 4–7.

Until the certificate exists, `build-app.sh` falls back to ad-hoc signing and
says so. That build is fine for your own use and is what every check above was
run against; it is **not** what you should upload.

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
3. ~~**Bump the version.**~~ **Set 2026-07-29** to `1.0.0` / `254` — see
   [Step 1](#step-1--pick-and-set-the-version). Bump again for the *next* release.
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

- `CFBundleShortVersionString` — the **marketing** version users see (e.g. `1.0.0`).
  Match this to your git tag.
- `CFBundleVersion` — a **monotonic build number** that must increase every time
  you notarize (Apple rejects a re-used build number). Bump it on every release.

Currently: `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 254`.

**Set 2026-07-29 for the first release.** `1.0.0` reflects a feature-complete
build: both providers ship, the reliability observation passed, and the icon and
release binary are in place. The build number is the repository's commit count
at the time of the bump, which keeps it monotonic without a second thing to
remember — regenerate it with:

```sh
git rev-list --count HEAD
```

Bump both on every release; Apple rejects a re-used build number at
notarization. Edit them in `CodexUsageMonitor/Resources/Info.plist`, then commit:

```sh
git add CodexUsageMonitor/Resources/Info.plist
git commit -m "Release 1.0.0"
```

Use **SemVer** (`MAJOR.MINOR.PATCH`). Being at `1.0.0` is a statement about the
feature set, not a promise that the Claude path is contractually settled — see
the terms caveat in the release notes below.

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

- If you see a **`Developer ID Application: … (TEAMID)`** line → Path A. The script
  picks it up automatically, or set it explicitly:
  ```sh
  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
  ```
  Then re-run the notarization-readiness checks above: the current `.build`
  bundle was signed **ad-hoc**, and only a rebuild with the real identity will
  print `Authority=Developer ID Application` and a `Timestamp=`.
- If you see nothing usable → Path B (ad-hoc). The script warns and continues; skip
  the notarization step and read [Path B](#path-b--no-paid-account-unsignedad-hoc).

## Step 3 (Path A) — Notarize and staple

Notarization = Apple scans your signed app and issues a ticket; **stapling**
attaches that ticket so it works offline.

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

Zip the **stapled** app (Path A) or the signed app (Path B). `ditto` preserves the
bundle structure and metadata that a plain `zip` can mangle:

```sh
cd CodexUsageMonitor/.build
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-1.0.0.zip
```

A `.zip` is perfectly good for a menu-bar app. A `.dmg` (drag-to-Applications
window) is nicer polish but optional — you can add one later with `create-dmg`.

## Step 5 — Tag the release

The tag is the immutable marker the GitHub Release is built from. Match it to
`CFBundleShortVersionString`, prefixed with `v`:

```sh
git tag -a v1.0.0 -m "Codex Usage Monitor 1.0.0"
git push origin v1.0.0
```

(Tag the commit that produced the binary you're shipping — usually `main` after the
PR merged.)

## Step 6 — Create the GitHub Release

### Option 1 — `gh` CLI (fastest, once authenticated)

`gh` is **not logged in**; authenticate first. The remote is already set to
`origin` → `github.com/chocolatechipscookiecrumbles/AgentUsageMonitor`, so `gh` picks
the repo up from the working tree.

```sh
gh auth login          # choose GitHub.com → HTTPS → follow the browser prompt
```

Then create the release and attach the zip in one command:

```sh
gh release create v1.0.0 \
  "CodexUsageMonitor/.build/CodexUsageMonitor-1.0.0.zip" \
  --title "Codex Usage Monitor 1.0.0" \
  --notes-file docs/release-notes/1.0.0.md
```

### Option 2 — Web UI

1. Go to **Releases → Draft a new release** in the repo.
2. Choose the tag `v1.0.0` (or create it there).
3. Title + notes (paste the notes below).
4. **Attach binaries** → drop in `CodexUsageMonitor-1.0.0.zip`.
5. **Publish** (no pre-release tick — this is a `1.x` build).

### The release notes

Already written: **[`docs/release-notes/1.0.0.md`](../release-notes/1.0.0.md)**.
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
     `xattr -dr com.apple.quarantine /Applications/CodexUsageMonitor.app`
```

## Step 7 — Verify the download like a stranger would

Don't trust the app you built; trust the artifact you uploaded. Download the zip
from the Release page to another folder (or another Mac), then:

```sh
# Simulate a fresh download's quarantine flag, then check Gatekeeper's verdict:
xattr -w com.apple.quarantine "0081;00000000;Safari;" ~/Downloads/CodexUsageMonitor.app
spctl -a -vvv ~/Downloads/CodexUsageMonitor.app
```

- Path A (notarized): `spctl` prints **`accepted … source=Notarized Developer ID`**.
- Path B: `spctl` **rejects** it — expected; users need the right-click-Open or
  `xattr` step from the notes.

## Path B — no paid account (unsigned/ad-hoc)

You can still ship, with a worse first-run experience:

1. Build normally; the script falls back to ad-hoc and warns you.
2. Skip notarization and stapling entirely.
3. Zip and release as above. Tick **pre-release** on the GitHub Release —
   not because `1.0.0` is unfinished, but because an unsigned build is not
   something to hand the public unqualified.
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

Version, icon, and notes are already in place for `1.0.0`, so from a working
Developer ID certificate this is the whole thing:

```sh
# 1. build + sign (script handles release config, assets, icns, nested signing)
cd CodexUsageMonitor && swift test && ./Scripts/build-app.sh
./Scripts/verify-signed-app-resources.sh
# 2. notarize + staple
cd .build && ditto -c -k --keepParent CodexUsageMonitor.app notarize.zip
xcrun notarytool submit notarize.zip --keychain-profile "notary-codexmon" --wait
xcrun stapler staple CodexUsageMonitor.app
xcrun stapler validate CodexUsageMonitor.app
# 3. package
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-1.0.0.zip
# 4. tag
cd ../.. && git tag -a v1.0.0 -m "Codex Usage Monitor 1.0.0" && git push origin v1.0.0
# 5. release
gh release create v1.0.0 CodexUsageMonitor/.build/CodexUsageMonitor-1.0.0.zip \
  --title "Codex Usage Monitor 1.0.0" --notes-file docs/release-notes/1.0.0.md
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
