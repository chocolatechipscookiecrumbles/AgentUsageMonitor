# Claude reset tracker portability diagnosis — 2026-09-23

## Conclusion

The display and reminder machinery can be reused; the automatic inventory source cannot currently be ported by copying Codex's decoder. No verified equivalent Claude inventory contract has been established. This is an evidence limitation, not proof that Anthropic has no internal endpoint.

## Codex path

`Quota/CodexProtocolModels.swift` reads `rateLimitResetCredits.availableCount` and `rateLimitResetCredits.credits[].expiresAt` from `account/rateLimits/read`. The values pass through `CodexQuotaSample` and `QuotaPresentation`. `Menu/CodexMenuPresentation.swift` selects a compact expiry subset; `Settings/AgentResetCreditsRow.swift` displays the count and full expiry list. `Notifications/QuotaNotifier.swift` uses the reset-credit setting and 24-hour/one-hour reminders.

The current notifier is Codex-specific: titles say Codex, and delivery keys use `credit-<expiry>-<window>`. A Claude port must namespace new keys by provider/offer identity, while retaining existing Codex keys to avoid replaying delivered alerts. The Settings row accepts a provider tint but its title still says Earned Reset Credits; a reusable row needs provider-specific wording, not a new Settings host.

## Claude evidence

- [Current official status-line schema](https://code.claude.com/docs/en/statusline) documents `rate_limits.five_hour` and `rate_limits.seven_day` utilization and `resets_at`; it does not document a redeemable reset inventory.
- [Official reset guidance](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset) establishes optional offers affecting a session or weekly limit and optional expiry. Redemption is in web/Desktop Settings > Usage. Scheduled quota resets and redeemed offers are different concepts; neither usage drops nor reset timestamps establish available inventory.
- The existing OAuth fixture and app decoder contain no verified inventory mapping. Crucially, `ClaudeOAuthUsageSource` explicitly ignores unknown JSON fields. Inspecting its normalized snapshot cannot prove the current raw endpoint omits offers.
- The previous audit used stored fixture/source evidence, not a new raw authenticated response. This follow-up makes no new Keychain read, CLI execution, or speculative endpoint request. A live inventory remains unverified.

## Smallest next diagnostic step

During one already-authorized successful ordinary OAuth read, inspect the raw response **before** `JSONDecoder` normalization using a temporary local diagnostic harness. Emit JSON key paths, value types, and array structure only; exclude credentials, headers, account identifiers, usage values, and transcript content. Bound the request with the existing timeout/backoff and silent credential policy. If silent access fails, record it and stop; never trigger Reconnect automatically or add production polling.

Compare the structure with an account known to have an offer and, when naturally available, one without. Obtain provider documentation or consistent sanitized observations establishing count, affected scope, available versus unavailable, stable offer identity, expiry units/timezone, and explicit empty inventory. A suggestive key name alone is insufficient. Remove temporary instrumentation and raw responses after inspection.

No verified field means retain **Available resets: Unavailable** plus **Open Claude Usage**. Do not scrape the website, probe guessed routes, execute automatic `/usage`, or infer redemption from disappearance.

## Diagnostic result — 2026-09-23

The temporary diagnostic ran from the Developer-ID-signed app executable with
`KeychainPromptPolicy.never`. The silent credential read succeeded, and one
request to the existing `/api/oauth/usage` endpoint returned HTTP 200. The
diagnostic emitted only JSON key paths and value shapes. It did not print or
persist the credential, headers, account identifiers, percentages, monetary
amounts, or reset timestamps. The temporary command and source file were then
removed.

Observed reset-shaped fields were:

- `five_hour.resets_at`: ISO-8601 string
- `seven_day.resets_at`: ISO-8601 string
- `limits[].resets_at`: ISO-8601 string

These belong to quota windows and are already supported. The response exposed
no named object or array containing a redeemable reset count, stable offer ID,
affected quota window, or offer expiry. This proves only that this account's
current response did not expose a usable inventory; it does not prove the
response shape for an account with an active offer.

The response also contained opaque optional top-level fields. One was
`omelette_promotional`, currently null. Inspection of the installed Claude
Desktop 2.7032.0 application schema shows that field has the same
`utilization`/`resets_at` shape as quota windows and is presented as a Claude
Design grant. It is not evidence of the five-hour/weekly **Reset for free**
inventory described by Anthropic. Claude Code 2.1.281 contains no corresponding
inventory field found by the targeted local check.

**Decision:** the Codex reset tracker cannot yet be ported with correct
semantics. Keep the unavailable state. The next evidence-producing observation
requires the same sanitized diagnostic while the account is known, from Claude
Settings > Usage, to have an active reset offer. Diffing that response against
this no-inventory baseline can identify a candidate field; a decoder still
requires verified zero/absent behavior, scope, identity, and expiry semantics.

## Existing Claude Code local records — 2026-09-24

A read-only structural scan covered all 32 JSONL files under Claude Code's local
projects directory. It emitted key paths, types, and counts only; no transcript
text, percentages, timestamps, identifiers, or credentials were printed.

Four system records across four files contain a structured `usageReport`.
Every one includes two `rate_limits.limits` entries:

- `kind: session`, `group: session`, with ISO-8601 `resets_at`
- `kind: weekly_all`, `group: weekly`, with ISO-8601 `resets_at`

Those records are sufficient to recover the scheduled reset date/time for the
ordinary session and weekly quota windows. They are sparse rather than a live
inventory: the newest observed local `usageReport` was about 35 hours old at
the time of this scan. The existing fresh status-line bridge remains the better
automatic source for the same quota-window resets.

The local schema contains no redeemable-reset count, offer identifier, affected
window, availability state, or offer-expiry field. A targeted search for
**Reset for free**, limit-reset availability, and reset-expiry wording found no
matching structured or text record. `extra_usage.used_credits` is spending data,
not reset-offer evidence.

**Local-record decision:** use these records only as potential retained quota
reset evidence if a future requirement needs it. They cannot supply the Codex-
style **Available resets** tracker or its offer-expiration reminders. No parser
change is justified for that tracker.

## Conditional port after verification

1. Extend `ClaudeUsageSnapshot` with an optional independently timestamped inventory only once its source contract is known; preserve backward cache decoding.
2. Distinguish absent inventory, explicit zero, and offers without expiry. Quota-only snapshots retain the last known inventory and its age; explicit empty replaces it.
3. Reuse the existing reset row and compact menu overflow treatment with **Available resets** wording; preserve the stable 340-point non-scrolling menu host.
4. Route fresh accepted inventory through `QuotaNotifier`, reuse the existing setting/windows/dedup store, and use Claude-specific stable offer keys. Stale retained inventory generates no new reminders. Preserve Codex's existing key format.
5. Use isolated fixtures for zero, missing, expired, non-expiring, multiple, and stale offers. Verify cache compatibility, disconnect clearing, no duplicate reminders after source changes/relaunch, and signed-app geometry/accessibility.

Implementation remains governed by [the reset-offer plan](../superpowers/plans/2026-09-22-claude-reset-offers.md). Source verification gates the decoder/reminders, not passive quota monitoring.
