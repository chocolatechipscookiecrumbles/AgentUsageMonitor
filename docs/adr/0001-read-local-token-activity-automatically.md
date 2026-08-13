---
status: accepted
---

# Read local token activity automatically

Codex Usage Monitor automatically performs field-scoped reads of known Codex and Claude local session roots while the app runs, even when provider quota is disconnected or unavailable, so Token Activity can remain useful without a separate setup control. This was chosen over explicit opt-in and popover-triggered scanning; the app decodes no conversation content, makes no network or model request, and must disclose the boundary in Data & Privacy.

## Amendment — 2026-07-28: cache reconciled requests across launches

The original decision kept the derived index in memory only, rebuilt from nothing after every launch. That made every launch show a reading state and repeat a full cold reconciliation of months of transcripts.

Reconciled requests are now cached in `token-activity-cache.json` under the app's Application Support directory, so a launch republishes the previous instance's result before reading any file. What is written stays inside the original decision's read boundary: hashed request identities, timestamps, model identifiers, and token counts — the same values the card already displays. No file path, provider session, turn, or event identifier, and no raw record is written, so the cache cannot reconstruct a conversation or name a project.

The cache is a head start, not a source of truth. What follows about scope is unchanged by the 2026-08-04 amendment below; only the moment reading becomes permitted has moved. A full rescan still runs at launch and on file events and replaces the cached set as soon as it completes; requests are re-aggregated against the current range, so a cache written yesterday reads as no activity today rather than as stale totals. Retention is fourteen days plus the single newest request — the widest window the card can report is the current local week, and two weeks covers it across a rollover and a time-zone change — which keeps Last Request answerable after a gap without storing history that no longer affects the card. A cache that is corrupt, tampered with, or written by a build with a different reconciliation contract is discarded rather than rendered, and an unreadable scan leaves the cached history alone instead of erasing it.

## Amendment — 2026-08-04: automatic only after explicit provider enrollment

"Automatically, while the app runs" turned out to mean "on first launch, before the user had agreed to anything." 0.0.1 shipped with no record of app-level consent, so it adopted whichever provider CLI sessions it found and began reading that provider's local records immediately. A user whose only relationship with this app was installing it arrived at a window already displaying their account and their machine's usage.

Local reads are now automatic *for an enrolled provider*. `ProviderEnrollmentStore` records `.notRequested`, `.enabled`, or `.disabled` per provider; before `.enabled`, that provider's Token Monitor does not scan, does not observe its roots, and holds no derived cache. After the user selects Connect, the original decision applies unchanged: reading follows app monitoring rather than quota availability, so local activity stays useful while that provider's quota is disconnected, failing, or unavailable.

The consent boundary moved; the read boundary did not. Field scoping, the absence of conversation content, the no-network guarantee, and the Data & Privacy disclosure are all as originally decided. Two consequences are deliberate. A 0.0.1 upgrade is treated as unenrolled, because that build stored nothing that distinguishes "the user chose this" from "a CLI session happened to exist" — the cost is one reconnect, and no provider CLI is signed out. And enrollment gates only *whether* an owner may start: once running, quota and Token Monitor keep separate state, so a failed quota sign-in cannot turn a valid local reading into an authentication error, and a missing local record cannot read as a disconnection.
