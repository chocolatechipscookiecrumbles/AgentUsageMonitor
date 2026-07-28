---
status: accepted
---

# Read local token activity automatically

Codex Usage Monitor automatically performs field-scoped reads of known Codex and Claude local session roots while the app runs, even when provider quota is disconnected or unavailable, so Token Activity can remain useful without a separate setup control. This was chosen over explicit opt-in and popover-triggered scanning; the app decodes no conversation content, makes no network or model request, and must disclose the boundary in Data & Privacy.

## Amendment — 2026-07-28: cache reconciled requests across launches

The original decision kept the derived index in memory only, rebuilt from nothing after every launch. That made every launch show a reading state and repeat a full cold reconciliation of months of transcripts.

Reconciled requests are now cached in `token-activity-cache.json` under the app's Application Support directory, so a launch republishes the previous instance's result before reading any file. What is written stays inside the original decision's read boundary: hashed request identities, timestamps, model identifiers, and token counts — the same values the card already displays. No file path, provider session, turn, or event identifier, and no raw record is written, so the cache cannot reconstruct a conversation or name a project.

The cache is a head start, not a source of truth. A full rescan still runs at launch and on file events and replaces the cached set as soon as it completes; requests are re-aggregated against the current day, so a cache written yesterday reads as no activity today rather than as stale totals. Retention is three days plus the single newest request, which keeps Last Request answerable after a gap without storing history that no longer affects the card. A cache that is corrupt, tampered with, or written by a build with a different reconciliation contract is discarded rather than rendered, and an unreadable scan leaves the cached history alone instead of erasing it.
