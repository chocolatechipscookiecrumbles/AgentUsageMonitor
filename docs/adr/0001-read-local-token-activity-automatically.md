---
status: accepted
---

# Read local token activity automatically

Codex Usage Monitor automatically performs field-scoped reads of known Codex and Claude local session roots while the app runs, even when provider quota is disconnected or unavailable, so Token Activity can remain useful without a separate setup control. This was chosen over explicit opt-in and popover-triggered scanning; the app decodes no conversation content, keeps the derived index in memory only, makes no network or model request, and must disclose the boundary in Data & Privacy.
