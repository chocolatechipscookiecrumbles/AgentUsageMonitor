# Menu-Popover Token Activity Card Implementation Plan

> **Status (2026-07-28): Feasible and queued by user direction.** This revision adds an intraday token graph and a line-by-line token breakdown to the existing menu-popover card. Implementation has not started.

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
- Do not persist provider file paths or raw JSONL lines. The first implementation keeps its activity index in memory and rebuilds it asynchronously after launch.
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

### Task 3: Add Claude streaming and sidechain reconciliation

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/ClaudeLocalActivitySource.swift`

**Consumes:** `~/.claude/projects/**/*.jsonl`, `~/.config/claude/projects/**/*.jsonl`, and valid comma-separated `CLAUDE_CONFIG_DIR` project roots.

- [ ] **Step 1:** Recursively enumerate regular `.jsonl` files without following symbolic links. Reuse the bounded reader; do not derive or publish a project name from the directory.
- [ ] **Step 2:** Decode only assistant timestamp, message ID, request ID, session ID, model, `isSidechain`, and input/output/cache creation/cache read fields. Recognize usage-bearing nested agent-progress envelopes without decoding message content.
- [ ] **Step 3:** Within a file, key streaming chunks by `(messageID, requestID)` and keep the newest/more complete cumulative usage record. Across files, prefer a non-sidechain parent record over a replayed sidechain copy of the same message.
- [ ] **Step 4:** Preserve a distinct sidechain response when it has its own message ID. For same-role duplicates, prefer the non-negative record with the larger complete token total, then the newer timestamp.
- [ ] **Step 5:** Normalize total as input + cache creation + cache read + output. Keep all four categories separate for rows and accessibility.
- [ ] **Step 6:** Unknown advisor/iteration usage is ignored for the first card and recorded as a limitation. Do not add nested counts to the parent without a stable identity and model rule.
- [ ] **Step 7:** Run fabricated streaming/replay/sidechain/malformed corpus probes and the sanitized live diagnostic. Require graph-total equality and output containing no content, path, project, session/account identifier, or credential.
- [ ] **Step 8:** Commit as `feat: reconcile local Claude activity`.

### Task 4: Own incremental scans and semantic updates

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityFileObserver.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

- [ ] **Step 1:** Wrap one recursive FSEvent stream for each provider root that exists. Debounce a burst for one second, coalesce paths, and emit only after writes settle; do not watch the whole home directory.
- [ ] **Step 2:** Make `LocalActivityMonitor` the only owner of sources, in-memory file metadata, parsed byte offsets, reconciliation state, per-file contributions, scan tasks, and observer lifetime.
- [ ] **Step 3:** On an unchanged `(size, modification time, parser producer key)`, reuse the in-memory contribution. On append, parse from the prior complete-line byte offset. On truncation/replacement/parser-version change, rebuild that file from zero.
- [ ] **Step 4:** Start scans automatically with app monitoring, regardless of quota/connection state. Publish `.loading`, scan every existing known provider root off the main actor, then publish `.available`, `.noActivity`, or sanitized `.unavailable`. Opening the popover is never the trigger.
- [ ] **Step 5:** Replace a changed file's contribution before re-aggregation so repeated file events cannot double-count.
- [ ] **Step 6:** Observe calendar-day, significant-time, and time-zone changes through system notifications. Rebuild buckets on those semantic events; do not add a midnight or chart polling timer.
- [ ] **Step 7:** On application activation, retry only roots previously absent. Opening/redrawing the popover must not start, scan, or refresh activity.
- [ ] **Step 8:** Add one monitor to `QuotaViewModel`, start it with app monitoring rather than quota availability, and stop it with app teardown. Keep all file metadata, byte offsets, reconciled requests, and aggregates in memory; every app launch rebuilds asynchronously.
- [ ] **Step 9:** Commit as `feat: monitor local token activity`.

### Task 5: Build the fixed graph-and-rows card

**Files:**

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityPresentation.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ProviderTokenActivityCard.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverTheme.swift`

**Produces:** **Token activity**, **This Mac · observed**, a Today headline, an intraday chart, provider-native category rows, Requests, multiple Model Usage rows, and Last Request.

- [ ] **Step 1:** Format token totals with locale-aware compact notation that preserves one decimal below 10K/10M boundaries and never rounds a positive count to `0`. Keep exact counts in accessibility.
- [ ] **Step 2:** Render a fixed-height 84-point Swift Charts plot:
  - one `BarMark` per Activity Interval, colored with the provider accent;
  - x domain from local midnight to the end of the current 30-minute interval, using the full plot width;
  - at most three x-axis labels (start, midpoint, current/end);
  - at most three y-axis labels (zero, midpoint, rounded maximum);
  - no legend, animation, scrolling, future intervals, projection, or click selection.
- [ ] **Step 3:** Reserve one fixed-height detail line above the plot. Its resting copy is `Hover over a bar for details`; hovering a bar changes only that line to an absolute range and compact total such as `14:00–14:30 · 141.6K tokens`. Implement hover inside a fixed chart overlay/caption envelope so it never resizes the card or changes the rows. Clear the visual selection when the pointer exits.
- [ ] **Step 4:** For all-zero/No Activity state, show the fixed empty plot frame and `No activity observed today`; do not synthesize bars.
- [ ] **Step 5:** Keep the four provider-native category rows, Requests, and Last Request structurally stable in every expanded state:

| Row | Codex value | Claude value |
| --- | --- | --- |
| 1 | Input | Input |
| 2 | Cached input | Cache creation |
| 3 | Output | Cache read |
| 4 | Reasoning | Output |
| 5 | Requests | Requests |
| Final | Last Request | Last Request |

- [ ] **Step 6:** Insert Model Usage between Requests and Last Request. Show up to three Short Model Name groups—including Unknown model when it ranks there—followed by `Other · N models` only when additional groups exist. Sort named rows by descending tokens, use alphabetical tie-breaking, and show compact tokens plus whole-percent share.
- [ ] **Step 7:** Use `Unavailable` for an unsupported category, not `0`. A valid observed zero may display `0` only when the containing source is available.
- [ ] **Step 8:** Format Last Request as a two-line row: compact total plus absolute local time, then Short Model Name. Use an abbreviated date when it predates today. Expose the exact provider-native token breakdown and full raw model identifier to accessibility.
- [ ] **Step 9:** Use compact, sanitized state copy:
  - Loading: `Reading activity…`
  - Local Records Missing: `No local records found` and `Use {provider} on this Mac to see activity here.`
  - Activity Unavailable: `Activity unavailable` and `Local records couldn't be read safely.`
  - No Activity: expanded `No activity observed today`
  Do not expose paths, parser details, or provider errors.
- [ ] **Step 10:** Supply an accessibility chart descriptor with every Activity Interval's absolute range and exact token value, plus the exact Today total. Keep the visual chart as one ordinary traversal element rather than exposing dozens of unlabeled bars. Make each detail row a separate combined element with exact values.
- [ ] **Step 11:** Put chart height, hover-detail height, plot insets, header spacing, row height, divider inset, and category-label width in `MenuPopoverTheme`; do not scatter geometry constants.
- [ ] **Step 12:** Commit as `feat: add token activity popover card`.

### Task 6: Insert the card without destabilizing the popover

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift`

- [ ] **Step 1:** Render `ProviderTokenActivityCard` after the Codex quota region and before credits when quota is available; keep the same activity card visible above Codex quota-recovery content when quota is unavailable.
- [ ] **Step 2:** Render the same card after the Claude quota region and before source/recovery content when quota is available; keep it visible above Claude quota-recovery content when quota is unavailable.
- [ ] **Step 3:** Keep one stable outer host around the provider switch, but preserve provider-intrinsic height: `providerContent` reports its natural vertical size and the shared 12-point content-to-footer gap remains outside the enum branches. Do not restore the superseded 207/288-point minimum-height floor.
- [ ] **Step 4:** Preserve the 340-point, non-scrolling popover. Measure compact loading/unavailable cards and expanded zero/available cards with zero, one, three, and four Model Usage rows. If the tallest normal state clips at the smallest supported screen, stop for a product/layout decision; do not silently hide rows or add a nested scroller.
- [ ] **Step 5:** Keep data updates semantic and non-animated while the menu is open. Hover may change only fixed-envelope chart selection/caption state; it must not publish through `QuotaViewModel` or resize the host. Plot geometry and existing row identities remain stable; adding/removing bounded Model Usage rows may resize the natural-height host exactly once per published snapshot.
- [ ] **Step 6:** Build the main macOS scheme and run existing menu presentation/provider-switch tests. Expected: exit status 0 and no unrelated expectation changes.
- [ ] **Step 7:** Commit as `feat: show token activity in provider tabs`.

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

- [ ] **Step 1:** Replace **Conversations — Never read** with **Conversation content — Never collected** and explain that the app automatically reads only timestamps, models, token counts, and opaque identifiers needed to prevent duplicate counts from known provider roots.
- [ ] **Step 2:** Add an in-memory activity entry to `LocalDataInventory`: automatic while the app runs, no app-owned history file, rebuilt after every launch, source records remain provider-owned.
- [ ] **Step 3:** Document the graph and rows as local-only, zero-token-cost, and separate from quota. Explain that missing/ephemeral records appear unavailable rather than zero.
- [ ] **Step 4:** Remove remaining claims that this scope has no chart, or that it will build a separate Dashboard window.
- [ ] **Step 5:** Record source-version evidence and newly observed limitations here without live counts, model history, identifiers, or paths.
- [ ] **Step 6:** Commit as `docs: document token activity scope`.

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
