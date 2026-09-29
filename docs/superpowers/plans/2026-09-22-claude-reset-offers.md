# Claude Reset Offers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans`, `swiftui-pro`, and `writing-for-interfaces`.

**Goal:** Show Claude redeemable reset offers when an existing automatic source verifies them, otherwise show an honest unavailable state with a direct Usage-page action.

**Architecture:** Verify provider fields before extending the normalized snapshot. Reuse Codex reset-credit rows, compact expiry presentation, notification preference, and expiry reminder windows only when Claude supplies a real inventory.

**Constraints:** Automatic sources only. Never infer offers from usage drops or scheduled quota resets, redeem an offer, scrape a browser, or manufacture an expiry.

## Tasks

- [x] Audit OAuth, status-line, and explicit `/usage` structures for count, identifier, scope, availability, expiry, and source capture time.
- [x] No verified inventory fields exist in the inspected sources; no speculative model added.
- [x] Show `Available resets: Unavailable` in Claude Settings. No inferred count or menu inventory.
- [x] Add one `Open Claude Usage` action shared with credit recovery.
- [x] No inventory exists, so no offer reminders or speculative inventory fixtures added.
- [x] Inspect unavailable state and Usage action in the signed app at the default Settings size, in Light/Dark and with the Context Rail hidden/visible.

## Source evidence and boundary — 2026-09-22

Follow-up: [September 23 portability diagnosis](../../development/claude-reset-tracker-portability.md) distinguishes reusable presentation/reminders from the unverified source contract. The OAuth decoder ignores unknown fields: absence from a fixture or normalized snapshot does not prove absence from a current raw response. The bounded check below therefore inspected sanitized raw field structure during a normal successful read.

That bounded live check is now complete. The current account response contained
ISO-8601 reset times for quota windows but no usable reset-offer inventory. The
installed Claude Desktop schema identifies the otherwise suggestive
`omelette_promotional` field as a Claude Design grant quota window. A second
sanitized observation while an offer is visibly active is required before any
inventory decoder or reminder implementation.

The September 24 local-record follow-up found four structured Claude Code
`usageReport` records. They include ISO-8601 reset times for the session and
weekly quota windows, but no redeemable-offer inventory or expiry. The newest
record was about 35 hours old, so local records neither replace the fresh
status-line source nor unlock the Codex-style reset-offer tracker.

The captured OAuth response in `ClaudeOAuthUsageSourceTests` contains quota
windows and their scheduled reset times, not redeemable offers. The status-line
bridge stores only quota percentages/reset epochs, and the existing manual
`/usage` parser extracts quota percentages and scheduled reset times, not an offer inventory. No live credential read or CLI probe
was performed for this audit.

[Anthropic's reset guidance](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset)
confirms that an offer may reset either session or weekly usage and may have its
own expiry. Redemption occurs in Claude web/Desktop and does not change credit
balance. Those product semantics do not establish an automatic inventory schema.
The implemented action opens `https://claude.ai/settings/usage`; it never redeems.

Signed-app default-size inspection confirmed the unavailable rows and Usage link
remain contained and readable in Light/Dark with the Context Rail hidden/visible.
The existing native controls remain keyboard-accessible.

## Acceptance

The app either displays verified provider data with its own timestamp or clearly says Unavailable and opens Claude Usage. Codex behavior remains unchanged.
