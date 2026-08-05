# Onboarding artwork — supplying the three intro images

The first-run tour has three pages, each with one image above its title and body.
Artwork is supplied out of band: `.gitignore` excludes
`CodexUsageMonitor/Resources/Assets.xcassets/` and every `*.png`, so these files
live only in your working copy, exactly like `AppIcon`.

## What to export

| Page | Imageset name | Subject |
| --- | --- | --- |
| 1 | `OnboardingWelcome` | The menu-bar popover showing Codex and Claude usage |
| 2 | `OnboardingProviders` | The two tabs, each with its own Connect button |
| 3 | `OnboardingPrivacy` | Local reading — usage totals, no prompts or responses |

**Format:** PNG, sRGB, with alpha if you want the window background to show
through. (PDF also works if your art is vector, but these are screen-like
compositions, so PNG is the right call.)

**Size:** the image region is **664 × 323 points**, so export at **1328 × 646
pixels** — exactly 2× for Retina. Anything close to that 2:1 ratio is fine:
the view uses `.resizable().scaledToFit()`, so the image scales down to fit and
is never cropped. What it will not do is scale *up*, so do not export smaller
than 1328 px wide or the art will look soft on a Retina display.

Because everything is scaled to fit, you do not need separate `@1x` and `@2x`
files. One image per page at 2× pixel dimensions, declared as a single
unscaled slot, is correct and simplest.

**Light and Dark:** the window uses `windowBackgroundColor`, which flips with the
system appearance, so art with a light background will look wrong in Dark mode.
Export a dark variant of each page. If you only have one variant, design it to
read acceptably on both — but two is better, and the catalog supports it.

**Safe margins:** keep meaningful content ~24 px in from every edge. The region
has no border or mask, but a subject that touches the edge reads as clipped.

## Where to put them

Each imageset directory already exists with an empty light slot and an empty dark
slot:

```
CodexUsageMonitor/Resources/Assets.xcassets/
├── Contents.json
├── OnboardingWelcome.imageset/Contents.json
├── OnboardingProviders.imageset/Contents.json
└── OnboardingPrivacy.imageset/Contents.json
```

### Option A — Xcode (easiest)

Open the catalog directly: **Xcode → File → Open…** and select
`CodexUsageMonitor/Resources/Assets.xcassets`. Each imageset appears with two
wells, "Any Appearance" and "Dark". Drag your PNG into each. Xcode writes
`Contents.json` for you.

### Option B — by hand

Copy the files in and name the `filename` keys to match. For example, in
`OnboardingWelcome.imageset/`, drop `welcome.png` and `welcome-dark.png`, then
edit its `Contents.json` to:

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "welcome.png"
    },
    {
      "appearances" : [
        { "appearance" : "luminosity", "value" : "dark" }
      ],
      "idiom" : "universal",
      "filename" : "welcome-dark.png"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

**A `filename` that names a file which is not there fails the build.** `actool`
errors rather than warning, so add the key and the file together. An empty slot
with no `filename` is valid — that is the state the scaffolding ships in.

## Checking your work

`Image(nsImage:)` resolves these through the compiled catalog in the app bundle,
so a plain `swift run` will **not** show them — it has no bundle. You need the
packaged app:

```sh
cd CodexUsageMonitor
bash Scripts/build-app.sh
open .build/CodexUsageMonitor.app --args --show-onboarding-preview
```

`--show-onboarding-preview` re-opens the tour without recording acknowledgement,
changing provider enrollment, or starting any provider monitoring, so you can
reopen it as many times as you like.

Note that `build-app.sh` also needs `AppIcon.appiconset` in this same catalog —
it is excluded from the repository too. Until you restore it from your private
copy, the script fails at `actool` before it reaches signing, and the onboarding
images cannot be verified in a packaged build.

## Accessibility

Each page carries a VoiceOver description in
`CodexUsageMonitor/Sources/CodexUsageMonitor/Onboarding/OnboardingPage.swift`
(`imageAccessibilityDescription`). They were written against the intended
subjects; once the real art exists, read them back and correct anything that no
longer describes what is on screen. An unlabeled decorative image is not
acceptable in a shipped tour.

## Rights

These are release inputs. Only use art you have redistribution rights to. If a
page shows a real provider's mark, confirm that use is permitted before it ships.
