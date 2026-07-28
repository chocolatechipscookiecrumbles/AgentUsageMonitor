# Shipping your first macOS release on GitHub

A practical, project-specific walkthrough for cutting the first downloadable
release of **Codex Usage Monitor** (`com.david.codex-usage-monitor`). It teaches
the *why* behind each step, not just the commands, so you can repeat it.

> **Read this first — personal-build caveat.** The README and the finalization
> plan record this as a **personal, non-commercial** build whose Claude path
> reuses Claude Code's Keychain credential, which Anthropic's ToS prohibits in
> absolute terms. A public GitHub Release *distributes* the app to anyone. Decide
> deliberately whether to publish it publicly. Safer options: mark the release
> clearly as a personal build, publish it in a **private** repo, or ship a
> **source-only** tag (no binary). The rest of this guide works the same either
> way — you choose what to attach.

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
   swift test          # expect: 0 failures
   ```
2. ~~**Build a *release* binary, not debug.**~~ **Resolved 2026-07-28:**
   `build-app.sh` builds `-c release` and installs the app executable and the
   bundled bridge from `.build/release/`. Override with `BUILD_CONFIGURATION=debug`
   only for local iteration — never for a release.
3. **Bump the version** in `CodexUsageMonitor/Resources/Info.plist`
   (see [Step 1](#step-1--pick-and-set-the-version)).
4. **Know the known gaps** so your release notes are honest:
   - **No app icon yet** (Workstream F is pending artwork) — the app ships with a
     generic icon until you add `AppIcon.appiconset`.
   - ~~**The Claude bridge needs `python3`.**~~ **Resolved:** the bridge is now a
     native Swift executable bundled and signed inside the app, so a clean Mac no
     longer needs Python.
   - **`LSUIElement` app:** it lives in the menu bar with no Dock icon — tell
     users where to look after launch.

## Step 1 — Pick and set the version

macOS apps carry two version strings in `Info.plist`:

- `CFBundleShortVersionString` — the **marketing** version users see (e.g. `0.1.0`).
  Match this to your git tag.
- `CFBundleVersion` — a **monotonic build number** that must increase every time
  you notarize (Apple rejects a re-used build number). Bump it on every release.

Currently: `CFBundleShortVersionString = 0.1.0`, `CFBundleVersion = 1`.

For the first release, `0.1.0` / `1` is fine. For the next one, bump both (e.g.
`0.1.1` / `2`). Edit them in `CodexUsageMonitor/Resources/Info.plist`, then commit:

```sh
git add CodexUsageMonitor/Resources/Info.plist
git commit -m "Release 0.1.0"
```

Use **SemVer** (`MAJOR.MINOR.PATCH`) and, while pre-1.0, treat `0.x` as "anything
may change." Given the personal-build status, staying on `0.x` is honest.

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

### Choosing the signing identity

Check what you have (this may raise a one-time Keychain prompt):

```sh
security find-identity -v -p codesigning
```

- If you see a **`Developer ID Application: … (TEAMID)`** line → Path A. The script
  picks it up automatically, or set it explicitly:
  ```sh
  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
  ```
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
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-0.1.0.zip
```

A `.zip` is perfectly good for a menu-bar app. A `.dmg` (drag-to-Applications
window) is nicer polish but optional — you can add one later with `create-dmg`.

## Step 5 — Tag the release

The tag is the immutable marker the GitHub Release is built from. Match it to
`CFBundleShortVersionString`, prefixed with `v`:

```sh
git tag -a v0.1.0 -m "Codex Usage Monitor 0.1.0"
git push origin v0.1.0
```

(Tag the commit that produced the binary you're shipping — usually `main` after the
PR merged.)

## Step 6 — Create the GitHub Release

### Option 1 — `gh` CLI (fastest, once authenticated)

`gh` is **not logged in** in this environment; authenticate first:

```sh
gh auth login          # choose GitHub.com → HTTPS → follow the browser prompt
```

Then create the release and attach the zip in one command:

```sh
gh release create v0.1.0 \
  "CodexUsageMonitor/.build/CodexUsageMonitor-0.1.0.zip" \
  --title "Codex Usage Monitor 0.1.0" \
  --notes-file docs/release-notes/0.1.0.md \
  --prerelease        # honest for a 0.x personal build; drop for a stable public release
```

### Option 2 — Web UI

1. Go to **Releases → Draft a new release** in the repo.
2. Choose the tag `v0.1.0` (or create it there).
3. Title + notes (paste the notes below).
4. **Attach binaries** → drop in `CodexUsageMonitor-0.1.0.zip`.
5. Tick **Set as a pre-release** for a `0.x` build; **Publish**.

### What to put in the release notes

Keep it a short, honest index. Suggested skeleton (save as
`docs/release-notes/0.1.0.md` if you use `--notes-file`):

```markdown
# Codex Usage Monitor 0.1.0

Personal, non-commercial build. Menu-bar usage monitor for Codex and Claude.

## Install
1. Download and unzip `CodexUsageMonitor-0.1.0.zip`.
2. Move `CodexUsageMonitor.app` to /Applications.
3. Launch it — it lives in the **menu bar** (no Dock icon).
   - *Unsigned build only:* if macOS blocks it, right-click the app → Open, or run
     `xattr -dr com.apple.quarantine /Applications/CodexUsageMonitor.app`.

## Requirements
- macOS 14 (Sonoma) or later.
- No Python or other runtime required — the Claude usage bridge is native.

## Known limitations
- No custom app icon yet.
- Claude usage reuses Claude Code's local credential (personal use only).
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
3. Zip and release as above, marked pre-release.
4. **Be explicit in the notes** that macOS will say the app "is damaged" or
   "cannot be opened," and give users the fix:
   ```sh
   xattr -dr com.apple.quarantine /Applications/CodexUsageMonitor.app
   ```
   (This clears the quarantine flag they'd otherwise be blocked by.)

This is fine for yourself and technical friends; it is not a good public
distribution story. If the app is worth publishing broadly, the $99/yr Developer
Program + Path A is the real fix.

## Quick reference — the whole flow (Path A)

```sh
# 1. version → Info.plist, commit
# 2. build + sign (release binary)
cd CodexUsageMonitor && swift test && swift build -c release && ./Scripts/build-app.sh
# 3. notarize + staple
cd .build && ditto -c -k --keepParent CodexUsageMonitor.app notarize.zip
xcrun notarytool submit notarize.zip --keychain-profile "notary-codexmon" --wait
xcrun stapler staple CodexUsageMonitor.app
# 4. package
ditto -c -k --keepParent CodexUsageMonitor.app CodexUsageMonitor-0.1.0.zip
# 5. tag
cd ../.. && git tag -a v0.1.0 -m "0.1.0" && git push origin v0.1.0
# 6. release
gh release create v0.1.0 CodexUsageMonitor/.build/CodexUsageMonitor-0.1.0.zip \
  --title "Codex Usage Monitor 0.1.0" --notes-file docs/release-notes/0.1.0.md --prerelease
```

## Where this can grow later

- **Automate it** with a GitHub Actions workflow triggered on `v*` tags (build,
  sign with secrets, notarize, upload). Do this once the manual flow is boring.
- **Auto-update** with [Sparkle](https://sparkle-project.org/) + an appcast, so
  users get new versions without re-downloading.
- **A `.dmg`** with a styled drag-to-Applications window for nicer first impressions.
- **Fix `build-app.sh`** to build `-c release` by default so the manual step in
  Step 2 disappears.
