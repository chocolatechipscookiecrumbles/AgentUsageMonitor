# Menu-Popover Token Activity Card Implementation Plan

> **Status (2026-07-28): Implemented through Task 7; one layout decision is open.** Both provider sources, the monitor, the card, its insertion into both tabs, and the documentation are done and verified against live records. The tallest normal Codex state measures 982 points, which clips in the deliberately non-scrolling popover on a typical laptop screen, so Task 6 Step 4's product/layout gate is unresolved and the signed-app visual, keyboard, and VoiceOver acceptance in Task 8 is recorded as **unobserved** rather than passed. See "Task 6 Step 4 gate" below.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact, privacy-safe **Token activity** card to the existing Codex and Claude menu-bar popover tabs. The card shows observed tokens through the current local day as an interval graph, followed by provider-appropriate token/request rows and multiple model-usage rows, without creating a separate page or window.

**Architecture:** A provider-neutral `LocalActivityMonitor` reads only allowlisted usage, model, timestamp, and opaque reconciliation fields from provider-owned local JSONL records. Provider parsers reconcile cumulative, streaming, restored, and sidechain records before emitting normalized requests. The monitor owns asynchronous initial scans, incremental file reads, half-hour aggregation, and immutable per-provider snapshots. `ProviderTokenActivityCard` renders one stable chart-and-rows card without starting a popover timer or changing quota collection.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Charts, Foundation, CryptoKit, Core Services `FSEventStream`, and provider-owned JSONL records; no third-party dependencies and no new network calls.

## Global Constraints

- Do not create a Dashboard window, Dashboard route, toolbar command, range picker, or separate page.
- Add one **Token activity** card to each supported provider tab:
  - Codex: quota card → Token activity card → credit balance card.
  - Claude: quota card → Token activity card → existing source/recovery content.
- The card is always scoped as **This Mac · observed**. Never present local records as account-wide usage, billing, quota consumption, or remaining allowance.
- Keep quota and activity pipelines separate. The card must not alter `QuotaMonitor`, `ClaudeUsageMonitor`, rate-limit validation, credits, refresh scheduling, or notification policy.
- Read only timestamp, model identifier, token counts, provider request/turn identifiers, and opaque session/fork/sidechain fields needed to reconcile duplicates. Never retain or publish prompts, responses, reasoning text, source code, tool inputs/outputs, project names, repository paths, working directories, transcript paths, account identifiers, or raw provider errors.
- Do not persist provider file paths or raw JSONL lines. **Revised 2026-07-28 by user direction:** reconciled requests are cached across launches so a new instance renders the previous instance's figures before rescanning. Only values the card already displays are written — hashed request identities, timestamps, model identifiers, and token counts. Per-file parser state, provider session/turn/event identifiers, paths, and raw records remain memory-only. See the amendment in `docs/adr/0001-read-local-token-activity-automatically.md`.
- Start field-scoped local activity reads automatically while the app runs for every known provider root that exists, including when quota is disconnected or unavailable. Do not add an opt-in preference or make opening the popover the scan trigger. This decision is recorded in `docs/adr/0001-read-local-token-activity-automatically.md`.
- Do not run `codex exec`, `claude -p`, `/usage`, an SDK query, or any other model turn. Collection must remain local and zero-token-cost.
- Do not use Codex `thread/resume`/`thread/fork` to recover usage. Do not install or require an OpenTelemetry collector.
- Preserve the 340-point, non-scrolling menu popover and its accepted provider-intrinsic height behavior. The selected provider reports its natural vertical size, the host grows or shrinks with bounded content, and one shared 12-point content-to-footer gap prevents overlap. Do not reintroduce a common provider-content minimum-height floor.
- Publish only semantic file-change results. Do not add per-second invalidation, `TimelineView`, a ticking child observable object, or a new polling loop in the popover.
- Treat absent roots, malformed/unsupported records, or unsafe reconciliation as Activity unavailable with factual copy. No Activity is reserved for a readable source with a valid zero-activity local day. Never substitute `0` for missing evidence.
- Follow the repository rule against feature-presence and happy-path tests. Verification uses sanitized corpus probes, source/privacy audits, existing tests, compilation, and signed-app acceptance.
- Production Swift changes require the main macOS `xcodebuild`, the narrowest relevant existing tests, and the signed `.app` built by `CodexUsageMonitor/Scripts/build-app.sh`.
- Update this plan, `docs/product/planning-board.md`, the daily-driver roadmap, `outline.md`, `how-to.md`, and `UsageProbe/README.md` whenever behavior, scope, evidence, or a limitation changes.

---

## Feasibility Decision

### Decision

The requested card and intraday graph are feasible for both providers as a **local observation**. They are not feasible as one authoritative, account-wide dashboard with identical provider semantics.

Both primary local sources include timestamps at response/event granularity, so reconciled events can be placed into 30-minute buckets from local midnight through the current bucket. The graph therefore does not need estimated interpolation or an account API. The difficult part is reconciliation, not charting:

- Codex records expose `last_token_usage` beside cumulative `total_token_usage`, but restored, forked, and interleaved counters can replay or decrease. A simple cumulative-total hash is insufficient.
- Claude records can repeat cumulative streaming chunks and can replay a parent message inside a sidechain/subagent file. UUID-only deduplication is insufficient.

The shared product contract is:

- **Today** — normalized tokens observed in provider-owned session records on this Mac since local midnight.
- **Activity Chart** — 30-minute token bars from local midnight through the current interval, not a cumulative or rolling graph. Each reconciled request contributes its normalized total to the Activity Interval containing the provider-recorded completion timestamp. Hover shows that interval's time range and token total without changing the summary rows.
- **Rows** — stable provider-native token categories followed by Requests, multiple Model Usage rows, and Last Request:
  - Codex categories: Input, Cached input, Output, Reasoning.
  - Claude categories: Input, Cache creation, Cache read, Output.
- **Model Usage** — group raw identifiers by a deterministic Short Model Name such as `GPT-5.6` or `Sonnet 4.5`, then show the top three groups ordered by contribution to Observed Tokens today, followed by `Other · N models` when additional groups exist. Each row shows the short name, compact token total, and whole-percent share. Requests without a usable identifier remain in **Unknown model**.
- **Last Request** — a compact two-line row for the newest reconciled local agent interaction, regardless of date: total tokens and absolute local time on line one, Short Model Name on line two. Use an abbreviated date when it predates today. Exact token categories and raw model identifier remain in accessibility.

Normalization rules:

- Codex total is the record's `total_tokens` when internally consistent, otherwise overflow-safe `input_tokens + output_tokens`. `cached_input_tokens` is a subset of input and `reasoning_output_tokens` is a subset of output; neither is added again.
- Claude total is overflow-safe `input_tokens + output_tokens + cache_creation_input_tokens + cache_read_input_tokens`, because Claude reports those input categories separately.
- The graph, Today headline, Model Usage rows, request count, and token rows must all be derived from the same reconciled request set. The sum of graph buckets must equal Today.
- The UI does not compare Codex totals with Claude totals or use local tokens to infer quota burn.
- Token Activity is independent from quota availability. A readable local source remains visible when provider quota is disconnected or unavailable.
- Every uniquely observed main-agent, subagent, and sidechain request contributes to the graph, Observed Tokens, Requests, and Model Usage. Replayed parent/cumulative records do not.
- Today means the current local calendar day from local midnight through now.
- Observed Tokens preserve provider-native normalization: Codex does not re-add cached/reasoning subsets; Claude adds its separately reported cache creation/read categories.
- Local scanning starts automatically with the app, is not gated by quota connection, and retains its derived index in memory only.
- Loading and Activity unavailable use a compact card with no chart or detail rows. No Activity is a valid expanded zero-day card with the graph frame and zero-valued available categories.

### Grilling decisions

Resolved on 2026-07-28:

- The graph shows tokens in each 30-minute Activity Interval, not a cumulative line.
- The exact interface label is **Last Request**.
- Model Usage shows the top three models plus an aggregated Other row when needed. Each row shows tokens and share; the graph remains one aggregate series.
- Token categories remain provider-native.
- Token Activity is rendered independently from provider quota availability.
- Last Request uses two lines: total tokens plus absolute time, then model.
- Unique subagent and sidechain activity is included everywhere; replayed copies are removed.
- Today is the current local calendar day.
- Observed Tokens use provider-native normalization and are not compared across providers.
- The popover retains dynamic provider-intrinsic height, natural vertical sizing, and the shared 12-point content-to-footer gap from the superseding July 26 window fix.
- Local scanning is automatic; no opt-in activity preference or popover-open scan trigger is added.
- The activity index is in memory only and rebuilt asynchronously after every launch.
- Loading and Activity unavailable are compact; a valid No Activity day expands to the normal graph/detail presentation.
- Requests are assigned to Activity Intervals by provider-recorded completion time.
- Missing model identifiers form an explicit Unknown model group.
- Other includes the combined-model count in its label.
- The Activity Chart uses bars with a fixed-height hover-detail line; hover never changes summary rows or card height.
- The chart spans local midnight through the current Activity Interval using the full plot width.
- Model Usage and Last Request use Short Model Names; raw identifiers remain in accessibility.
- Last Request may predate today.
- Local Records Missing, Activity Unavailable, and No Activity remain distinct sanitized states.

### Evaluated provider sources

| Provider/source | What it exposes | Feasibility | Decision |
| --- | --- | --- | --- |
| Codex `account/usage/read` | Stable lifetime summary and daily token buckets in the installed `codex-cli 0.144.1` schema | Good account aggregate; no request timestamps, model history, or latest-request breakdown | Keep as a future account-level cross-check; do not mix it into this local card |
| Codex `thread/tokenUsage/updated` | Per-thread `last` and `total` input/cached/output/reasoning totals | Official app-server event, but live delivery belongs to threads started/resumed by that app-server client | Do not attach the monitor to user threads merely to obtain usage |
| Codex `~/.codex/sessions/**/*.jsonl` | Opaque session/fork/turn identifiers, model context, timestamped `last_token_usage` and cumulative `total_token_usage` | Sufficient for event-level rows and intraday buckets; requires cumulative-counter and fork reconciliation | Primary Codex source |
| Claude OAuth `/api/oauth/usage` | Quota utilization, reset times, scoped limits, and extra-usage credits | Authoritative quota source; no general per-request history | Keep in the quota pipeline only |
| Claude `statusLine` JSON | Documented model, prompt ID, last-call context/current usage, and rate-limit fields | Useful latest-response validation; repeated renders do not provide a durable history identity | Retain as quota fallback/validation, not historical aggregation |
| Claude `~/.claude/projects/**/*.jsonl` and `~/.config/claude/projects/**/*.jsonl` | Timestamped assistant usage, message/request/session identifiers, model, cache creation/read, input/output, and sidechain metadata | Sufficient for event-level rows and intraday buckets; requires streaming and sidechain reconciliation | Primary Claude source |
| Claude OpenTelemetry | Exact request/model/token metrics with request IDs | Official, but requires user configuration and an external collector; default exports can contain identity attributes | Out of scope for the default personal card |
| Claude Agent SDK result/model usage | Per-model usage for sessions owned by the SDK caller | Does not observe the user's existing interactive Claude Code sessions | Not a collection source |

### Open-source implementation research

Research was performed against repository source on 2026-07-28, not screenshots or secondary descriptions.

#### CodexBar patterns to adopt

- CodexBar reads known Codex/Claude JSONL roots on device and labels those totals as local-log estimates.
- Its cache tracks file size, modification time, parsed byte offset, per-file rows, and a producer/schema version. Unchanged files are skipped; appended bytes are read incrementally; parser changes invalidate stale caches.
- Its Codex scanner does not trust cumulative totals blindly. It keeps a monotonic watermark, suppresses exact re-emissions, detects component decreases/interleaving, contains deltas after a drop, and resolves inherited fork baselines where possible.
- Its Claude scanner keeps the final cumulative chunk for a `(messageId, requestId)` pair, reconciles duplicates across files, prefers a non-sidechain parent copy, and tracks cache creation/read separately.
- Its menu chart uses Swift Charts with fixed geometry, sparse axes, semantic colors, bounded hover selection, and an explicit accessibility label/value.

Patterns not copied:

- CodexBar's graph is a multi-day **cost** bar chart with scrollable model/session detail. This card reuses only its fixed-geometry hover discipline for an intraday **token** bar chart; it does not add daily cost selection or scrollable details.
- Pricing, costs, projects, conversation lists, and network-fetched model catalogs remain outside this scope.

Primary source:

- <https://github.com/steipete/CodexBar>
- <https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner.swift>
- <https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner%2BClaude.swift>
- <https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Vendored/CostUsage/CostUsageCache.swift>
- <https://github.com/steipete/CodexBar/blob/main/Sources/CodexBar/CostHistoryChartMenuView.swift>

#### ccusage patterns to adopt

- ccusage recursively reads both supported Claude project roots, supports multiple `CLAUDE_CONFIG_DIR` roots, filters for usage-bearing lines before decoding, skips malformed lines, and applies the selected time zone before grouping.
- Its normalized Claude total includes input, output, cache creation, and cache read.
- It deduplicates exact `(messageId, requestId)` pairs and separately handles sidechain copies that replay the same message under another request ID. A non-sidechain parent wins over a replay; otherwise the more complete token record wins.
- Its reporting model retains separate token categories and per-model breakdowns. Its five-hour block report also demonstrates that timestamped request rows support rate and time-bucket aggregation.

Patterns not copied:

- ccusage is a CLI/reporting engine, not a compact native chart design.
- Parallel whole-history reporting, pricing, projections, and billing-block heuristics are unnecessary for a one-day menu card.

Primary source:

- <https://github.com/ccusage/ccusage>
- <https://github.com/ccusage/ccusage/blob/main/rust/adapters/claude/src/lib.rs>
- <https://github.com/ccusage/ccusage/blob/main/rust/adapters/claude/src/daily.rs>
- <https://github.com/ccusage/ccusage/blob/main/docs/guide/blocks-reports.md>

### Evidence already collected

- The installed Codex schema generated with `codex app-server generate-json-schema --experimental` defines `GetAccountTokenUsageResponse`, `ThreadTokenUsage`, and `TokenUsageBreakdown`.
- OpenAI documents `thread/tokenUsage/updated` for app-server-driven/resumed threads: <https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md>.
- Anthropic documents status-line model, prompt ID, last-call usage, and event-driven/zero-token behavior: <https://code.claude.com/docs/en/statusline>.
- Anthropic documents exact model/token telemetry as an optional OpenTelemetry export: <https://code.claude.com/docs/en/monitoring-usage>.
- Sanitized live probes on 2026-07-28 selected only timestamps, field-presence flags, model identifiers, request identifiers, and token fields. The sampled Codex rollout contained timestamped last/cumulative usage events; the sampled Claude transcript contained timestamped, identified usage records. No conversation content, identifier value, or project path was recorded in this plan.

### Known limitations and implementation gate

- Local totals exclude activity on other Macs and provider surfaces that do not write these records.
- Codex ephemeral threads and Claude `--no-session-persistence` sessions are invisible.
- Codex model attribution comes from the nearest applicable turn context; a backend reroute may make it the configured rather than final served model.
- Codex fork/interleave behavior has multiple historical shapes. The implementation must pass the sanitized reconciliation corpus in Task 2 before any UI work begins. If the scanner cannot make graph-total equality and replay restraint hold, stop at the source boundary and record the unsupported shape.
- Claude sidechain/advisor formats continue to evolve. Unknown nested usage types are ignored until independently understood; they are not guessed into the total.
- Provider JSONL layouts are not stable public APIs. Unknown records are ignored, and a complete parse failure becomes **Activity unavailable**, not zero.
- Thirty-minute buckets intentionally trade minute-level detail for a readable 340-point card. They do not estimate activity between observed events.
- Dynamic height is bounded by the four fixed category rows, Requests, at most four Model Usage rows, the two-line Last Request, and fixed chart geometry. A semantic activity update may resize the host; it must not animate or tick.

---

## File Structure

### New files

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityModels.swift` — provider-neutral requests, buckets, breakdowns, and state.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivitySource.swift` — source protocol, scan bounds, and sanitized scan results.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityJSONLReader.swift` — bounded forward/incremental JSONL byte reader.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/CodexLocalActivitySource.swift` — Codex cumulative/fork reconciliation and model attribution.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/ClaudeLocalActivitySource.swift` — Claude streaming/sidechain reconciliation.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityFileObserver.swift` — recursive, debounced FSEvents wrapper.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift` — one owner for scans, cursors, file events, buckets, and snapshots.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityPresentation.swift` — compact formatting and state-to-copy mapping.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityCard.swift` — fixed chart, token-category rows, bounded Model Usage list, and Last Request.

### Modified files

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — owns and publishes the one activity monitor.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift` — inserts the card between quota and credits.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift` — inserts the card below quota.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverTheme.swift` — owns card/chart/row metrics.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift` — states the exact field-scoped read boundary.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LocalDataInventory.swift` — documents the in-memory derived state.
- `UsageProbe/README.md`, `how-to.md`, `outline.md`, `docs/product/planning-board.md`, and `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md` — synchronize product scope and privacy guidance.

---

### Task 1: Define one reconciliation and chart contract

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityModels.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivitySource.swift`

**Interfaces:**

```swift
struct LocalActivityTokenBreakdown: Sendable, Equatable {
    let inputTokens: Int64
    let cacheCreationTokens: Int64?
    let cachedInputTokens: Int64?
    let outputTokens: Int64
    let reasoningOutputTokens: Int64?
    let totalTokens: Int64
}

struct LocalActivityRequest: Sendable, Equatable, Identifiable {
    let id: String
    let provider: AgentProvider
    let occurredAt: Date
    let modelID: String?
    let tokens: LocalActivityTokenBreakdown
}

struct LocalActivityBucket: Sendable, Equatable, Identifiable {
    let id: Date
    let startedAt: Date
    let totalTokens: Int64
}

struct LocalActivityModelShare: Sendable, Equatable {
    let shortName: String
    let sourceModelIDs: [String]
    let totalTokens: Int64
    let fraction: Double
}

struct ProviderLocalActivitySnapshot: Sendable, Equatable {
    let provider: AgentProvider
    let dayStartedAt: Date
    let generatedAt: Date
    let todayTokens: LocalActivityTokenBreakdown
    let requestCount: Int
    let buckets: [LocalActivityBucket]
    let modelUsage: [LocalActivityModelShare]
    let lastRequest: LocalActivityRequest?
}

enum ProviderLocalActivityUnavailability: Sendable, Equatable {
    case localRecordsMissing
    case unsafeToRead
}

enum ProviderLocalActivityState: Sendable, Equatable {
    case loading
    case available(ProviderLocalActivitySnapshot)
    case noActivity(dayStartedAt: Date, lastRequest: LocalActivityRequest?)
    case unavailable(ProviderLocalActivityUnavailability)
}
```

- [ ] **Step 1:** Make breakdown construction provider-specific and overflow-safe. Reject negative/inconsistent records; do not silently clamp malformed evidence into a plausible request.
- [ ] **Step 2:** Define `LocalActivityScanResult` as reconciled sanitized requests plus opaque per-file cursors and one source status. It must not contain a raw line, URL, path, project name, or provider error.
- [ ] **Step 3:** Aggregate one local-calendar day into 30-minute Activity Intervals using `Calendar.autoupdatingCurrent`. Assign each reconciled request wholly by its provider-recorded completion timestamp. Include interval starts from midnight through the current interval; fill observed quiet intervals with zero, omit future intervals, and handle 23/25-hour daylight-saving days through calendar arithmetic rather than a fixed 48-element assumption.
- [ ] **Step 4:** Derive the local-calendar Today range, category totals, request count, Model Usage, Last Request, and chart buckets in one pure aggregation boundary. Include uniquely observed main-agent, subagent, and sidechain requests. Require `sum(buckets.totalTokens) == todayTokens.totalTokens`.
- [ ] **Step 5:** Normalize raw model identifiers through a small local table/parser into a Short Model Name consisting only of family plus model number (`GPT-5.6`, `Sonnet 4.5`, `Opus 4.1`, `Haiku 4.5`). Strip provider/product prefixes, dated build suffixes, and Codex product suffixes. Group identifiers that resolve to the same short name, preserve the contributing raw IDs for accessibility, and use Unknown model when no safe short name exists.
- [ ] **Step 6:** Rank Short Model Name groups by normalized total with alphabetical tie-breaking. Publish the first three groups and aggregate every remaining group into `Other · N models` without losing tokens. Select Last Request across all observed dates by timestamp then stable ID.
- [ ] **Step 7:** Build the main macOS scheme. Expected result: exit status 0 with the new domain types unused.
- [ ] **Step 8:** Commit as `feat: define token activity domain`.

### Task 2: Prototype and gate Codex reconciliation

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityJSONLReader.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/CodexLocalActivitySource.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/LocalActivityReconciliationRegressionTests.swift`
- Modify: `docs/superpowers/plans/2026-07-14-dashboard.md` with sanitized findings.

**Consumes:** `~/.codex/sessions/**/*.jsonl`.

- [x] **Step 1:** At the public `CodexLocalActivitySource.scan(bounds:)` seam, add exactly one deterministic regression method named `testExactCumulativeReplayDoesNotInflateObservedTokens`. It creates a temporary fabricated Codex JSONL root containing one accepted usage event followed by an exact cumulative replay and asserts that the sanitized scan publishes one unique request whose total matches the first event. Do not add another automated activity test, a feature-presence assertion, or a live-source dependency.
- [x] **Step 2:** Run only that regression and record RED before implementation. The expected failure is that `CodexLocalActivitySource` does not yet exist or that the repeated cumulative record is counted twice.
- [x] **Step 3:** Implement a byte-offset JSONL reader that reads asynchronously in bounded chunks, carries an incomplete trailing line, and returns the next offset. Cap one line at 8 MiB; skip a larger line without logging it and continue at the next newline.
- [x] **Step 4:** Enumerate regular `.jsonl` files without following symbolic links. Keep paths inside the source call and identify cached scan state with an opaque SHA-256 file ID.
- [x] **Step 5:** Decode only timestamp, record type, opaque session/fork/turn identifiers, model identifier, `last_token_usage`, and `total_token_usage`. Do not decode content-bearing payloads into the activity domain.
- [x] **Step 6:** Build a per-session totals tracker modeled on the proven CodexBar constraints:
  - suppress exact cumulative-total re-emissions;
  - keep a per-component monotonic watermark;
  - prefer a non-negative total delta only when it cannot exceed the reported last usage;
  - latch interleaved mode when any cumulative component drops;
  - after latching, count only growth above the watermark, capped by reported last usage;
  - resolve an explicit parent/fork baseline when the local metadata makes it available;
  - never count a copied parent prefix as child activity.
- [x] **Step 7:** Attribute accepted deltas to the active model/turn and event timestamp. Build the published request ID as SHA-256 of provider tag + opaque session/turn/event identity + reconciled totals. Never publish the source identifiers.
- [x] **Step 8:** Create a temporary sanitized corpus outside the production bundle containing monotonic totals, exact replay, restored copy, counter reset, interleaved high/low lineage, missing total, and truncated-line shapes. Use only fabricated identifiers and counts.
- [x] **Step 9:** Run the scanner against that corpus and a field-scoped live probe. Record only accepted-event count, rejected/replayed count, graph-total equality, model-presence flag, and newest timestamp. No prompt, response, identifier, path, project, or account field may appear.
- [x] **Step 10:** Run the one regression GREEN. Then temporarily bypass exact-replay suppression, confirm the same regression fails, restore the implementation, and run it GREEN again. Record all three commands/results without committing the temporary mutation.
- [x] **Step 11:** If replay restraint or graph-total equality fails, stop before Tasks 3–6 and document the unsupported counter shape. Do not compensate in the chart layer.
- [x] **Step 12:** Build the main macOS scheme and commit as `feat: reconcile local Codex activity`.

#### Task 2 evidence — 2026-07-28

- The sole regression was RED before implementation because `CodexLocalActivitySource` was absent, GREEN after implementation, failed with request count `2` instead of `1` when exact-replay suppression was temporarily bypassed, and returned to GREEN after restoration. Every focused run executed exactly one XCTest method.
- A temporary, non-bundled fabricated corpus covered monotonic totals, exact replay, restored copy, counter reset, interleaved high/low lineage, missing total, and a truncated trailing line. Sanitized result: accepted-event count `6`; rejected/replayed count `6`; graph-total equality `true`; model-presence flag `true`; newest timestamp `2026-07-28T04:00:01Z`.
- The first field-scoped live probe accepted no events and exposed that provider timestamps include fractional seconds. After the source was corrected to accept fractional and whole-second ISO-8601 timestamps, the final sanitized live result was: accepted-event count `12806`; rejected/replayed count `10684`; graph-total equality `true`; model-presence flag `true`; newest timestamp `2026-07-28T05:23:58Z`.
- `xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/codex-task2-derived build` exited `0` with `** BUILD SUCCEEDED **`. The build retained the pre-existing `kSecUseAuthenticationUIFail` deprecation warning.
- Limitation: the fabricated corpus and diagnostic harness were temporary artifacts outside the repository, not maintained automated coverage. Per the approved regression boundary, only exact cumulative replay is retained as an XCTest; other counter shapes remain manual source-boundary acceptance.

#### Task 2 review revision evidence — 2026-07-28

- The source now fails closed with `.unsafeToRead` when a complete JSONL record is malformed, a usage record is missing or has unsupported evidence, token values are invalid, or any reconciliation addition overflows. Arithmetic overflow is no longer swallowed as a prior counted value.
- A child session with usage-bearing events now requires a resolvable parent/fork baseline; an unresolved fork is `.unsafeToRead` rather than a guessed partial contribution.
- Once a cumulative component drop latches interleaved mode, each component contributes only `max(0, current - watermark)`, capped by the matching reported-last component. A fabricated lower-than-watermark row contributed zero.
- Root traversal and recursive enumeration now use directory-relative descriptors with `O_NOFOLLOW`; every opened descriptor is validated as a directory or regular file before use. Fabricated ancestor-symlink and final-file-symlink cases were both refused.
- The JSONL reader now feeds each completed bounded line directly into selective decoding. It retains only the current line buffer and sanitized parser state, not an array of raw lines.
- Request identity now prefers an allowed provider event/request ID. Its fallback hashes provider, opaque session/turn identity, timestamp, cumulative/last usage evidence, reconciled delta, and model evidence; it excludes path, inode cursor, and byte offset. Fabricated move and same-content replacement scans produced the same request ID.
- The disposable non-XCTest review harness exited `0` and emitted only: malformed usage `unsafeToRead`; unresolved fork `unsafeToRead`; below-watermark accepted delta `0`; symlink ancestor refused `true`; symlink final target refused `true`; movement identity stable `true`; replacement identity stable `true`; graph-total equality `true`. The harness and corpus were removed after the run.
- `env CLANG_MODULE_CACHE_PATH=/tmp/codex-task2-review-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-task2-review-swiftpm swift test --disable-sandbox --scratch-path /tmp/codex-task2-review-build --filter 'LocalActivityReconciliationRegressionTests/testExactCumulativeReplayDoesNotInflateObservedTokens'` exited `0`; exactly one XCTest ran with zero failures. The fixture uses `/private/tmp` because macOS `/var` is a symlink and the descriptor traversal intentionally refuses symlink ancestors.
- `xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/codex-task2-review-derived build` exited `0` with `** BUILD SUCCEEDED **`. Xcode retained its multiple-matching-destination warning; the focused SwiftPM build also retained the pre-existing `kSecUseAuthenticationUIFail` deprecation warnings.
- Limitation: the expanded safety and counter-shape matrix remains temporary manual source-boundary acceptance under the approved one-regression-method constraint.

#### Task 2 parser and identity review revision — 2026-07-28

- Complete records now require a non-empty top-level structural type. `event_msg` records require a non-empty payload subtype; present non-token subtypes remain ignorable. `token_count` records require a session identity, turn identity, timestamp, usage object, and explicit input, cached-input, output, and reasoning-output components in every present last/total object. An optional reported total must equal input plus output.
- Request IDs no longer use delimiter concatenation. SHA-256 input is a count-prefixed sequence of length-prefixed UTF-8 fields containing the provider tag, session identity, turn identity, provider event/request ID or timestamp/usage/model fallback, reconciled delta, and reconciled-total evidence. Provider event IDs are therefore scoped by session and turn rather than assumed globally unique.
- A fresh disposable non-XCTest harness exited `0`: `{}` produced `.unsafeToRead`; empty `last_token_usage` and `total_token_usage` objects produced `.unsafeToRead`; and the same provider event ID in two sessions produced two requests with two distinct IDs. The harness and corpus were removed.
- The sole focused XCTest command using `/tmp/codex-task2-identity-build` exited `0`; exactly one test ran with zero failures. No test method was added.
- `xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/codex-task2-identity-derived build` exited `0` with `** BUILD SUCCEEDED **`. Xcode retained its multiple-matching-destination warning.
- Compatibility boundary: a legacy Codex usage row that omits cached-input or reasoning-output evidence now makes that scan unavailable instead of silently treating the missing component as zero. This is intentional fail-closed behavior for the supported four-component contract.

#### Task 2 final review revision — 2026-07-28

The final Task 2 review found three defects that source inspection alone had missed, because every prior diagnostic ran as a CLI harness with a 1048576-descriptor limit and every prior *live* probe predated the strict-parser revision.

- **Unbounded open descriptors.** The source opened every `.jsonl` file under the sessions root before parsing any of them and held all descriptors for the whole scan. That root grows without bound (237 files on the development Mac already), so under a GUI application's descriptor limit the scan would throw and Codex activity would be permanently **Activity unavailable**. Traversal now lives in a shared `LocalActivityFileTraversal` that reads and closes each file as it is reached, holding at most one file descriptor per directory depth. A live scan under a deliberately lowered 64-descriptor limit returned the same accepted count as the unrestricted scan.
- **`errno` poisoned across skipped entries.** The traversal loop reset `errno` only at the bottom of each iteration, so any `continue` path (a non-`.jsonl` sibling, a duplicate inode) could leave a stale value and turn normal end-of-directory into `.unsafeFilesystem`. `errno` is now cleared immediately before each `readdir`.
- **Two fail-closed rules rejected valid provider records.** Against the real Codex root the scan returned `.unsafeToRead` outright:
  - Codex emits rate-limit-only `token_count` records whose `info` is null — 18 of 23,733 sampled `token_count` payloads. These make no usage claim, so they are now ignorable like any other non-usage subtype instead of missing evidence.
  - Codex emits usage objects whose reported `total_tokens` disagrees with `input_tokens + output_tokens` — 151 of 47,279 sampled usage objects. This plan's normalization rule already says to use the reported total only when internally consistent and `input + output` otherwise, so an inconsistent reported total is now ignored rather than fatal. Component values still decide the total, and every other component requirement stays strict.

A present-but-incomplete usage object (a usage object missing an explicit component) remains `.unsafeToRead`, so the documented fail-closed four-component contract is unchanged for records that do claim usage.

Sanitized disposable-harness output after the corrections:

```text
live status readable: true
live accepted-event count: 13037
live cold-scan seconds: 7.23
live graph-total equality: true
live model-presence flag: true
live today request count: 599
live readable under low descriptor limit: true
live count stable under low descriptor limit: true
rate-limit-only record readable: true
incomplete usage object unsafeToRead: true
symlink ancestor refused: true
symlink final target refused: true
mixed-directory readable: true
absent root localRecordsMissing: true
```

The harness, its fabricated corpus, and its staged source copies were removed after the run. The sole focused regression exited `0` with one XCTest method and zero failures; no test method was added. `xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme CodexUsageMonitor -destination 'platform=macOS' -derivedDataPath /tmp/cum-derived build` exited `0` with `** BUILD SUCCEEDED **`.

Recorded limitation: the 7.23-second cold live scan is a full-history rebuild. Task 4 owns incremental byte-offset reuse so this cost is not repeated per semantic update; Task 8 measures cold and append-only scans.

### Task 3: Add Claude streaming and sidechain reconciliation

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/ClaudeLocalActivitySource.swift`

**Consumes:** `~/.claude/projects/**/*.jsonl`, `~/.config/claude/projects/**/*.jsonl`, and valid comma-separated `CLAUDE_CONFIG_DIR` project roots.

- [x] **Step 1:** Recursively enumerate regular `.jsonl` files without following symbolic links. Reuse the bounded reader; do not derive or publish a project name from the directory.
- [x] **Step 2:** Decode only assistant timestamp, message ID, request ID, session ID, model, `isSidechain`, and input/output/cache creation/cache read fields. Recognize usage-bearing nested agent-progress envelopes without decoding message content.
- [x] **Step 3:** Within a file, key streaming chunks by `(messageID, requestID)` and keep the newest/more complete cumulative usage record. Across files, prefer a non-sidechain parent record over a replayed sidechain copy of the same message.
- [x] **Step 4:** Preserve a distinct sidechain response when it has its own message ID. For same-role duplicates, prefer the non-negative record with the larger complete token total, then the newer timestamp.
- [x] **Step 5:** Normalize total as input + cache creation + cache read + output. Keep all four categories separate for rows and accessibility.
- [x] **Step 6:** Unknown advisor/iteration usage is ignored for the first card and recorded as a limitation. Do not add nested counts to the parent without a stable identity and model rule.
- [x] **Step 7:** Run fabricated streaming/replay/sidechain/malformed corpus probes and the sanitized live diagnostic. Require graph-total equality and output containing no content, path, project, session/account identifier, or credential.
- [x] **Step 8:** Commit as `feat: reconcile local Claude activity`.

#### Task 3 evidence — 2026-07-28

A field-scoped survey of the local Claude roots preceded implementation and shaped the reconciliation rules. Only key names, presence flags, relationship classifications, and counts were recorded:

- Every assistant usage record carries a top-level `type`, a `message.id`, a `requestId`, a `timestamp`, `isSidechain`, and all four usage components. No line failed to parse and no record lacked a type, so no shape required guessing.
- Repeated `(message id, request id)` pairs occur up to six times. In all 1,220 repeated pairs, `output_tokens` was non-decreasing and the other three components never varied, confirming these are cumulative streaming chunks rather than separate requests.
- `usage.iterations` is present as a nested one-element list. Per Step 6 it is not decoded and not added to the parent; that remains a recorded limitation.
- The local corpus contained no cross-file or sidechain replay of the same message. Those rules are therefore exercised only by the fabricated corpus, not by live evidence.

Because Anthropic message identifiers are unique per response, the published request identity is the SHA-256 of the provider tag plus the message identifier alone. That keeps one stable identity per logical request across rescans no matter which copy of a message wins reconciliation, which is what makes repeated file events converge instead of accumulating.

The source decodes strictly less than the plan's Step 2 allowlist permits: session identifiers are never decoded, because message identity alone is sufficient to reconcile. Working directories, git branches, project names, tool payloads, and message content have no corresponding fields on the `Decodable` types at all.

Sanitized disposable-harness output:

```text
streaming accepted count: 1
streaming total tokens: 170
sidechain replay accepted count: 1
sidechain replay total tokens: 180
distinct sidechain accepted count: 2
distinct sidechain total tokens: 380
replay winner prefers parent over larger sidechain: true
repeated scan identity stable: true
missing cache component unsafeToRead: true
mixed transcript readable: true
mixed transcript accepted count: 1
synthetic readable: true
synthetic accepted count: 0
absent roots localRecordsMissing: true
live status readable: true
live accepted-request count: 1899
live cold-scan seconds: 0.18
live identities unique: true
live graph-total equality: true
live category math matches today: true
live model shares sum to one: true
live model-presence flag: true
live today request count: 60
live last request is newest accepted: true
```

The fabricated corpus deliberately embedded a working directory, a git branch, a session identifier, and message content; none reached published state, and the harness emitted only aggregates. The harness, corpus, and staged source copies were removed after the run.

Two shared defects were found and corrected while validating against live records:

- **Short Model Name required a minor version.** `claude-sonnet-5` and `claude-opus-5` — 728 of 3,864 live assistant records, and the newest models in use — resolved to **Unknown model**. The rule now accepts a single-component version, still recognizes the version when it precedes the family (`claude-3-5-sonnet`), and bounds each version component to one or two digits so a dated build suffix such as `-20251001` is never read as a minor version. Verified: `claude-sonnet-5=Sonnet 5`, `claude-opus-5=Opus 5`, `claude-opus-4-8=Opus 4.8`, `claude-haiku-4-5-20251001=Haiku 4.5`, `claude-sonnet-4-5-20250929=Sonnet 4.5`, `gpt-5.6-codex=GPT-5.6`, `gpt-5-codex=GPT-5`, `claude-3-5-sonnet-20241022=Sonnet 3.5`, `<synthetic>=Unknown model`.
- **A blank line failed a whole provider.** Both sources treat an undecodable complete line as unsafe evidence, so a single stray newline anywhere under a provider root would have made that provider permanently unavailable. The bounded reader now skips empty lines, which carry no record, before selective decoding sees them.

Zero-token assistant messages (Claude writes them for synthetic entries) are not observed requests and are excluded, matching the Codex source's treatment of a zero reconciled delta. This keeps them out of Requests and out of Model Usage.

Limitation: nested `usage.iterations` advisor/iteration usage remains un-ingested, and cross-file/sidechain replay handling is backed by fabricated corpus evidence only, because the live corpus contains no such replay.

### Task 4: Own incremental scans and semantic updates

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityFileObserver.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

- [x] **Step 1:** Wrap one recursive FSEvent stream for each provider root that exists. Debounce a burst for one second, coalesce paths, and emit only after writes settle; do not watch the whole home directory.
- [x] **Step 2:** Make `LocalActivityMonitor` the only owner of sources, in-memory file metadata, parsed byte offsets, reconciliation state, per-file contributions, scan tasks, and observer lifetime.
- [x] **Step 3:** On an unchanged `(size, modification time, parser producer key)`, reuse the in-memory contribution. On append, parse from the prior complete-line byte offset. On truncation/replacement/parser-version change, rebuild that file from zero.
- [x] **Step 4:** Start scans automatically with app monitoring, regardless of quota/connection state. Publish `.loading`, scan every existing known provider root off the main actor, then publish `.available`, `.noActivity`, or sanitized `.unavailable`. Opening the popover is never the trigger.
- [x] **Step 5:** Replace a changed file's contribution before re-aggregation so repeated file events cannot double-count.
- [x] **Step 6:** Observe calendar-day, significant-time, and time-zone changes through system notifications. Rebuild buckets on those semantic events; do not add a midnight or chart polling timer.
- [x] **Step 7:** On application activation, retry only roots previously absent. Opening/redrawing the popover must not start, scan, or refresh activity.
- [x] **Step 8:** Add one monitor to `QuotaViewModel`, start it with app monitoring rather than quota availability, and stop it with app teardown. Keep all file metadata, byte offsets, reconciled requests, and aggregates in memory; every app launch rebuilds asynchronously.
- [x] **Step 9:** Commit as `feat: monitor local token activity`.

#### Task 4 evidence — 2026-07-28

Ownership deviates from Step 2 in one respect, deliberately. The monitor owns which sources exist, when they scan, observer lifetime, the reconciled request set, and everything published. Each source owns its own per-file parse cache, because the parsed representation is provider-specific and privacy-sensitive; handing decoded transcript state to a shared monitor would widen the boundary that Tasks 2 and 3 worked to keep narrow. Sources are therefore actors rather than structs.

The monitor replaces a provider's whole reconciled request set on every scan instead of merging per-file contributions. Whole-set replacement is what makes repeated file events idempotent, and it is strictly safer than assembling incremental suffixes across two providers whose identity strategies differ. Scan bounds and cursors remain on the source seam for a future incremental publisher; the monitor passes empty bounds.

Incremental reuse lives in the traversal, which now fingerprints each file by opaque ID, size, and modification time and asks the source whether to skip it, resume from a cached parser state and byte offset, or rebuild. Only growth beyond the bytes already parsed counts as an append; anything shorter rebuilds, so a truncated or replaced file cannot resume past its own end.

Two performance defects were found while measuring, both of which made the cache nearly worthless:

- Sorting hashed inside the comparator. `reconcile` and `parentBaselines` computed a SHA-256 identity for both operands of every comparison, roughly 700,000 digests per full scan. Ordering keys are now computed once per event.
- The ordering identity was recomputed on every scan. It is now hashed when a record is first parsed, so it lives in the parse cache and a rescan of unchanged history pays nothing for it.

Measured on the live roots, cold versus fully cached rescan:

```text
codex cold seconds: 3.47 count: 13037     (was 7.64 before the sort fixes)
codex cached seconds: 0.61 count: 13037   (was 5.53 before the sort fixes)
claude cold seconds: 0.18 count: 1951
claude cached seconds: 0.07 count: 1951
```

Sanitized incremental-behavior output:

```text
first scan count: 1 total: 120
unchanged rescan count: 1 total: 120
unchanged rescan identical: true
after append count: 2 total: 190
append preserved first identity: true
append rescan stable: true
after truncation count: 1 total: 12
after removal status localRecordsMissing: true
after removal count: 0
codex cached count stable: true
claude cached count stable: true
```

The full suite executed 299 tests with 0 failures — the 298-test baseline plus the single approved Task 2 regression. No test was added for this task.

Limitations: the file observer holds an unretained reference to itself in its FSEvents context, so `stop()` must run before it is released; the monitor owns observers for the application's lifetime, which is the only case that occurs in the app. FSEvents is not started for a root that does not exist, because that would watch its future parents; absent roots are retried on application activation instead. The observer discards changed paths rather than coalescing them, since a transcript path is a project name.

### Task 5: Build the fixed graph-and-rows card

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityPresentation.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityCard.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverTheme.swift`

**Produces:** **Token activity**, **This Mac · observed**, a Today headline, an intraday chart, provider-native category rows, Requests, multiple Model Usage rows, and Last Request.

- [x] **Step 1:** Format token totals with locale-aware compact notation that preserves one decimal below 10K/10M boundaries and never rounds a positive count to `0`. Keep exact counts in accessibility.
- [x] **Step 2:** Render a fixed-height 84-point Swift Charts plot:
  - one `BarMark` per Activity Interval, colored with the provider accent;
  - x domain from local midnight to the end of the current 30-minute interval, using the full plot width;
  - at most three x-axis labels (start, midpoint, current/end);
  - at most three y-axis labels (zero, midpoint, rounded maximum);
  - no legend, animation, scrolling, future intervals, projection, or click selection.
- [x] **Step 3:** Reserve one fixed-height detail line above the plot. Its resting copy is `Hover over a bar for details`; hovering a bar changes only that line to an absolute range and compact total such as `14:00–14:30 · 141.6K tokens`. Implement hover inside a fixed chart overlay/caption envelope so it never resizes the card or changes the rows. Clear the visual selection when the pointer exits.
- [x] **Step 4:** For all-zero/No Activity state, show the fixed empty plot frame and `No activity observed today`; do not synthesize bars.
- [x] **Step 5:** Keep the four provider-native category rows, Requests, and Last Request structurally stable in every expanded state:

| Row | Codex value | Claude value |
| --- | --- | --- |
| 1 | Input | Input |
| 2 | Cached input | Cache creation |
| 3 | Output | Cache read |
| 4 | Reasoning | Output |
| 5 | Requests | Requests |
| Final | Last Request | Last Request |

- [x] **Step 6:** Insert Model Usage between Requests and Last Request. Show up to three Short Model Name groups—including Unknown model when it ranks there—followed by `Other · N models` only when additional groups exist. Sort named rows by descending tokens, use alphabetical tie-breaking, and show compact tokens plus whole-percent share.
- [x] **Step 7:** Use `Unavailable` for an unsupported category, not `0`. A valid observed zero may display `0` only when the containing source is available.
- [x] **Step 8:** Format Last Request as a two-line row: compact total plus absolute local time, then Short Model Name. Use an abbreviated date when it predates today. Expose the exact provider-native token breakdown and full raw model identifier to accessibility.
- [x] **Step 9:** Use compact, sanitized state copy:
  - Loading: `Reading activity…`
  - Local Records Missing: `No local records found` and `Use {provider} on this Mac to see activity here.`
  - Activity Unavailable: `Activity unavailable` and `Local records couldn't be read safely.`
  - No Activity: expanded `No activity observed today`
  Do not expose paths, parser details, or provider errors.
- [x] **Step 10:** Supply an accessibility chart descriptor with every Activity Interval's absolute range and exact token value, plus the exact Today total. Keep the visual chart as one ordinary traversal element rather than exposing dozens of unlabeled bars. Make each detail row a separate combined element with exact values.
- [x] **Step 11:** Put chart height, hover-detail height, plot insets, header spacing, row height, divider inset, and category-label width in `MenuPopoverTheme`; do not scatter geometry constants.
- [x] **Step 12:** Commit as `feat: add token activity popover card`.

### Task 6: Insert the card without destabilizing the popover

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift`

- [x] **Step 1:** Render `ProviderTokenActivityCard` after the Codex quota region and before credits when quota is available; keep the same activity card visible above Codex quota-recovery content when quota is unavailable.
- [x] **Step 2:** Render the same card after the Claude quota region and before source/recovery content when quota is available; keep it visible above Claude quota-recovery content when quota is unavailable.
- [x] **Step 3:** Keep one stable outer host around the provider switch, but preserve provider-intrinsic height: `providerContent` reports its natural vertical size and the shared 12-point content-to-footer gap remains outside the enum branches. Do not restore the superseded 207/288-point minimum-height floor.
- [x] **Step 4:** Preserve the 340-point, non-scrolling popover. Measure compact loading/unavailable cards and expanded zero/available cards with zero, one, three, and four Model Usage rows. If the tallest normal state clips at the smallest supported screen, stop for a product/layout decision; do not silently hide rows or add a nested scroller.
- [x] **Step 5:** Keep data updates semantic and non-animated while the menu is open. Hover may change only fixed-envelope chart selection/caption state; it must not publish through `QuotaViewModel` or resize the host. Plot geometry and existing row identities remain stable; adding/removing bounded Model Usage rows may resize the natural-height host exactly once per published snapshot.
- [x] **Step 6:** Build the main macOS scheme and run existing menu presentation/provider-switch tests. Expected: exit status 0 and no unrelated expectation changes.
- [x] **Step 7:** Commit as `feat: show token activity in provider tabs`.

### Task 7: Correct privacy and operating documentation

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LocalDataInventory.swift`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `docs/superpowers/plans/2026-07-14-dashboard.md`

- [x] **Step 1:** Replace **Conversations — Never read** with **Conversation content — Never collected** and explain that the app automatically reads only timestamps, models, token counts, and opaque identifiers needed to prevent duplicate counts from known provider roots.
- [x] **Step 2:** Add an in-memory activity entry to `LocalDataInventory`: automatic while the app runs, no app-owned history file, rebuilt after every launch, source records remain provider-owned.
- [x] **Step 3:** Document the graph and rows as local-only, zero-token-cost, and separate from quota. Explain that missing/ephemeral records appear unavailable rather than zero.
- [x] **Step 4:** Remove remaining claims that this scope has no chart, or that it will build a separate Dashboard window.
- [x] **Step 5:** Record source-version evidence and newly observed limitations here without live counts, model history, identifiers, or paths.
- [x] **Step 6:** Commit as `docs: document token activity scope`.

### Task 8: Verify privacy, reconciliation, performance, and signed-app presentation

**Files:**

- Modify: `docs/superpowers/plans/2026-07-14-dashboard.md` with dated evidence only.

- [ ] **Step 1:** Run from `CodexUsageMonitor`:

```bash
xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' build
```

Expected: exit status 0. Record warnings precisely.

- [ ] **Step 2:** Run the sanitized Codex/Claude reconciliation corpora, then the narrowest existing activity-adjacent and menu/provider-switch tests. Do not add feature-presence tests.
- [ ] **Step 3:** Require, for each provider: accepted requests are unique, graph sum equals Today, category math matches Today, model shares sum within floating-point tolerance, and the newest accepted request is the displayed Last Request.
- [ ] **Step 4:** Inspect diagnostic output and implementation to confirm raw lines, content, and paths cannot enter published state, errors, logging, accessibility, or diagnostics.
- [ ] **Step 5:** Measure cold and append-only scans with realistic large files while the UI remains responsive. Record elapsed time, bytes parsed on append, and peak memory. A semantic update must not trigger an unnecessary full-history scan.
- [ ] **Step 6:** Build and verify the signed app:

```bash
bash Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app
```

- [ ] **Step 7:** Inspect the actual popover in Light and Dark with available, No Activity, Local Records Missing, Activity Unavailable, one-bar, sparse, dense, long-raw-model, alias-collision, Unknown model, large-count, and older-Last-Request states.
- [ ] **Step 8:** At the smallest supported screen, verify the shortest and tallest Codex/Claude states remain fully reachable without scrolling or clipping. Confirm the host shrinks and grows to natural height, retains the shared 12-point footer gap, and leaves no artificial empty provider region.
- [ ] **Step 9:** Keep the popover open across a real append event, a Model Usage row-count change, repeated provider switches, and repeated hover entry/exit across every bar. Confirm each semantic snapshot causes at most one host resize, hover causes none, the graph and rows reconcile, and there is no duplicated/displaced content, stale hit testing, highlight displacement, overlap, or per-second redraw.
- [ ] **Step 10:** Verify pointer, keyboard, and VoiceOver traversal after updates. Pointer hover must identify the visibly targeted interval; VoiceOver must receive the exact interval series and Today total through the chart descriptor.
- [ ] **Step 11:** Inspect Data & Privacy at 680 × 560 with Context Rail hidden/visible in Light/Dark. Confirm copy wraps and all content remains reachable.
- [ ] **Step 12:** Record any unavailable visual/performance boundary honestly. Compilation and source inspection are not substitutes for signed-app interaction evidence.

### Tasks 5–7 evidence — 2026-07-28

Task 5 (card), Task 6 (insertion), and Task 7 (documentation) are implemented. The popover host was not modified: `MenuBarPopoverView` already keeps one stable outer host, `.fixedSize(horizontal: false, vertical: true)` on `providerContent`, and the shared 12-point content-to-footer gap outside the enum switch, so no minimum-height floor was reintroduced.

Compact-notation formatting keeps one decimal (`141.6K`) rather than the platform default (`142K`), because rounding to three significant digits hides the difference between similar days on a card whose whole purpose is comparison. A positive count never renders as `0`; it falls back to its exact value. Exact counts stay in accessibility everywhere.

Hover is owned entirely by the card's own `@State`. It changes the fixed-height detail line and the highlighted bar's opacity, and nothing else. It does not publish through `QuotaViewModel`, and it cannot resize the host because the detail line's height is reserved whether or not a bar is hovered.

#### Geometry measurements

Measured with a disposable `NSHostingView` harness at the 308-point popover content width, then deleted. No state overflowed horizontally — every measured width was exactly 308.0.

```text
loading:                  83.0
localRecordsMissing:     102.0
unsafeToRead:            102.0
noActivity, no last:     282.0
noActivity, with last:   331.0
available, 1 model row:  365.0
available, 3 model rows: 403.0
available, 4 model rows: 422.0   (also the 5- and 6-group cases: Other caps the list at four)
available, dark:         422.0
available, one bar:      365.0
```

Model Usage is correctly bounded: five and six distinct model groups both render four rows, because the fourth is the aggregated `Other · N models`.

#### Task 6 Step 4 gate: the tallest normal state clips

Composing the tallest Codex tab from measured parts:

```text
tab strip                            44.0
provider header                      58.0
content (quota 149 + activity 422 + credits 136, at 12-point spacing)   731.0
shared content-to-footer gap         12.0
action footer                       137.0
total                               982.0
```

982 points exceeds the usable height below the menu bar on a typical laptop display — roughly 931 points on a 13.6-inch MacBook Air at default scaling, and roughly 775 points at 1280×800. The popover is deliberately non-scrolling, so the tallest normal state would clip.

Per Step 4 this is a stopping point for a product/layout decision, not something to work around. No row was hidden, no nested scroller was added, and no geometry was silently shrunk. Before the card ships enabled by default, one of these needs a decision:

1. Make the card's detail rows collapsible, with the chart and Today headline always visible.
2. Drop Model Usage from the popover and keep it for a Settings surface.
3. Shorten the chart and tighten row spacing, which recovers roughly 40–60 points and is not enough on its own.
4. Accept a scrolling popover, which contradicts the current global constraint.

#### Task 8 status

Completed: `xcodebuild` on the main macOS scheme exited `0` with `** BUILD SUCCEEDED **`; the full suite executed 299 tests with 0 failures; `bash Scripts/build-app.sh` produced a Developer ID-signed bundle and `codesign --verify --deep --strict --verbose=2` reported `valid on disk` and `satisfies its Designated Requirement`; reconciliation corpora and live probes for both providers recorded graph-total equality, category math, unique identities, model shares summing to one, and the newest accepted request equalling the displayed Last Request; the privacy audit confirmed the decoded field set excludes content, paths, project names, and session identifiers.

**Unobserved:** every signed-app visual, pointer-hover, keyboard, VoiceOver, and Light/Dark check in Steps 7 through 11. These were not performed and must not be recorded as passed. Two reasons: the height gate above means the tallest state is known to clip, so visual acceptance should follow the layout decision rather than precede it; and launching the bundle to drive the popover can raise a Keychain/SecurityAgent prompt, which is not an acceptable side effect of an automated audit. The geometry evidence above comes from an isolated hosting harness, which the repository's own rules correctly treat as insufficient for final visual acceptance.

### Post-implementation revision — 2026-07-28 (user direction)

Two changes were requested after reviewing the rendered card.

#### Two-column metrics, and Requests as a header caption

The four token categories and Requests were five full-width rows whose values sat far right of short labels, spending vertical space the popover cannot afford and leaving the middle empty.

Pairing them into two columns was the first step, but five cells split three-and-two, which put Output beneath Cached input on the left and stranded Reasoning at the top right — the input/output pairing the split was meant to preserve. Moving Requests out of the grid fixed both problems at once: it is a count of interactions rather than a token category, so it belongs with the day's total, and removing it leaves a clean two-by-two.

Requests now reads as a caption directly under the headline total (`599 requests`, singular `1 request`, grouped by locale). The categories form a two-by-two grid filled top-down, so Codex shows Input/Cached input left and Output/Reasoning right, and Claude shows Input/Cache creation left and Cache read/Output right. Its exact count stays in accessibility under the `Requests` label.

Re-measured at the 308-point content width, with no horizontal overflow in either provider:

```text
                        original   two columns   Requests moved
card, 4 model rows         422.0         384.0            369.0
card, 1 model row          365.0         327.0            312.0
card, no activity          282.0         244.0            229.0
composed Codex content     731.0         693.0            678.0
total Codex popover        982.0         944.0            929.0
```

The Task 6 Step 4 gate is now **marginal rather than clearly failing**. 929 points fits within roughly 931 usable points on a 13.6-inch MacBook Air at default scaling — with nothing to spare — and still exceeds the ~775 points available at 1280×800. A longer provider header, a cached-quota warning strip, a connection-recovery card, or the notification-permission strip each add height on top of this, so the tallest *real* state can still exceed a 13.6-inch screen. Applying the same two-column treatment to Model Usage remains the next lever and would recover roughly 40 more points; it was not done because it was not requested. Signed-app verification at the smallest supported screen is still required before this gate can be called closed.

#### Cached activity across launches

Rebuilding from nothing on every launch meant the card always opened in a reading state and repeated a full cold reconciliation. `LocalActivityCache` now persists reconciled requests to `token-activity-cache.json` in the app's Application Support directory, and `LocalActivityMonitor.start()` republishes them before opening a file.

Design points that keep this inside the privacy boundary:

- Only values the card already displays are written: hashed request identities, timestamps, model identifiers, and token counts. No path, provider session/turn/event identifier, per-file parser state, or raw record is persisted, so the cache cannot reconstruct a conversation or name a project.
- Requests, not snapshots, are cached, and they are re-aggregated against the current day at load. A cache written yesterday therefore reads as no activity today rather than as stale totals — the day boundary needs no special handling.
- Retention is three days plus the single newest request, so Last Request still has an answer after a long gap without storing history that no longer affects the card.
- Synthesized `Codable` decoding bypasses the validating initializer, so every loaded request is re-validated by re-deriving its provider-normalized total. A tampered, corrupt, or foreign-schema cache is discarded rather than rendered.
- An `.unsafeToRead` scan leaves the cached history alone instead of erasing it, because an unreadable scan says nothing about what was previously observed.
- A full rescan still runs at launch and on file events and replaces the cached set when it lands. The cache is a head start, not a source of truth, so it does not weaken the "never fabricate a zero" rule.

Sanitized cache diagnostics (disposable harness, since deleted):

```text
CACHE retained recent only: true
CACHE tokens preserved: true
CACHE keeps newest when all are old: true
CACHE rejects tampered total: true
CACHE rejects corrupt file: true
CACHE rejects unknown schema: true
```

This supersedes the original in-memory-only constraint. The first *scan* of a launch is still a cold reconciliation (Codex ~3.5 s on the development corpus); only the display is instant. Persisting per-file parser state would also remove that cost but would write decoded provider session, turn, and event identifiers, which is a materially wider boundary and was not adopted.

## Explicitly Deferred

- Separate Dashboard window or route.
- Longer ranges, range pickers, cross-provider comparisons, forecasts, costs, projects, tools, skills, sessions, and inferred causes.
- Click selection, row filtering by interval, and per-model chart series.
- Account-wide model or latest-request usage; neither personal provider source exposes that complete contract.
- Rendering Codex `account/usage/read` account totals in the local card.
- Claude OpenTelemetry collector setup or nested advisor/iteration ingestion.
- A local-activity opt-in preference, persistent activity history, CloudKit, widgets, Watch, export, deletion, and local-activity notifications.

## Completion Criteria

- Codex shows quota → Token activity → credits; Claude shows quota → Token activity → source/recovery content.
- Each card says **This Mac · observed**, has an intraday Activity Chart of 30-minute bars with fixed-envelope hover detail, Today total, provider-native token rows, bounded Short Model Name groups, and Last Request.
- The graph is built from reconciled 30-minute request increments; its sum and every displayed category reconcile to Today.
- Codex cumulative/fork replay and Claude streaming/sidechain replay are restrained before aggregation.
- Source reads emit only allowlisted fields and cost no tokens.
- Field-scoped scans begin automatically while the app runs, remain independent of quota availability, and create no persistent activity index.
- Missing or unsupported evidence is unavailable/no activity, never a fabricated zero.
- The popover remains 340 points wide and non-scrolling, grows or shrinks to bounded natural content height with the shared footer gap, and remains usable across provider switches/file events with pointer, keyboard, and VoiceOver.
- Data & Privacy and operating documentation accurately describe the local read boundary.
- `xcodebuild`, relevant existing tests, signed-app build/signature, reconciliation corpus, privacy audit, performance check, and required visual acceptance have recorded successful evidence.

## Self-Review

- **Requested surface:** The plan adds a 30-minute token bar chart with hover detail, provider-native token lines, bounded Short Model Name groups, and Last Request inside the existing provider card; no separate page/window returns.
- **Feasibility:** Both providers have event timestamps and token categories. Source research shows the graph is feasible after reconciliation, not from naïve line counting.
- **Research adoption:** Incremental byte-offset scans, producer-key invalidation, cumulative containment, streaming replacement, and sidechain preference come from current CodexBar/ccusage source patterns. Their costs, pricing, long-range reports, and interactive details remain out of scope.
- **Privacy:** Domain values, source results, errors, storage, UI, and diagnostics exclude content and paths. Opaque lineage fields exist only to prevent duplicate counts.
- **Geometry:** The chart, provider-native categories, bounded Model Usage list, and Last Request have explicit envelopes, absolute time, no timer, and a smallest-screen signed-app gate.
- **Repository test policy:** No broad feature-presence or happy-path tests are added. Evidence uses temporary fabricated reconciliation corpora, existing tests, builds, source audit, and signed-app inspection.
