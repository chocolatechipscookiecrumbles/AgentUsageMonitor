AI Usage Monitor for macOS

Product and Engineering Plan

1. Product vision

Build a privacy-first native macOS application that monitors provider-reported and locally observed usage across Claude Code, OpenAI Codex, and GitHub Copilot. Describe data as authoritative only when its collection path and scope have been verified.

The application should help users answer five practical questions:

1. How much usage do I have left?
2. When will each limit reset?
3. Am I likely to hit a limit before the reset?
4. What caused a recent increase in usage?
5. Which provider is best positioned for my next task?

The first release will be a personal-use macOS application distributed outside the Mac App Store. Preserve clean provider boundaries so a later commercial release is possible, but treat Mac App Store compatibility as a separate feasibility gate after authentication and sandbox requirements are known.

⸻

2. Initial product scope

Platform and distribution

* Personal-use macOS application
* Distributed outside the Mac App Store
* Signed with Developer ID when shared beyond the developer's own Mac
* Notarized by Apple when shared beyond the developer's own Mac
* Native SwiftUI interface
* Menu-bar-first experience
* Launch-at-login support
* macOS widgets after the collection layer is stable
* Apple Watch complication after a companion/watchOS target and CloudKit synchronization are proven
* Optional iPhone companion later
* No proprietary backend
* CloudKit for sanitized cross-device snapshots
* Local-first storage and processing
* Existing open-source parsing where practical
* Official authentication and usage APIs wherever available
* Clear separation between official, locally observed, calculated, and estimated values

Initial providers

* Claude Code
* OpenAI Codex
* GitHub Copilot Student

Initial data categories

* Remaining short-term quota
* Remaining weekly or monthly quota
* Reset date and countdown
* Input tokens
* Output tokens
* Cache creation tokens
* Cache read tokens
* Requests
* Sessions
* Models
* Projects
* Tools and skills used, where reliably observable
* Subagent activity, where reliably observable
* Estimated API-equivalent cost
* Usage velocity
* Forecasted time to exhaustion
* Historical usage
* Official versus local discrepancies
* Provider availability and authentication health

⸻

3. Core product principles

3.1 Actual provider data first

The app should prefer provider-reported quota values over locally estimated values.

Source priority:

Official documented API
→ Documented provider-owned CLI or status interface
→ Verified provider-owned local cache
→ Opt-in authenticated provider dashboard (experimental)
→ Local usage records
→ Calculated estimate
→ Last cached value

Every metric must display its authority:

* Official API
* Official CLI
* Authenticated provider dashboard
* Local observation
* Calculated
* Estimated
* Cached
* Stale
* Unavailable

3.2 Local-first privacy

The app should process all detailed activity on the Mac.

The following should remain local:

* Authentication credentials
* Raw logs
* Prompt contents
* Responses
* Source-code contents
* Full repository paths
* Session transcripts
* Tool inputs and outputs
* Browser cookies
* CLI credential files

CloudKit should only receive sanitized summaries needed for widgets and Watch complications.

3.3 No hidden model usage

The application should not call an LLM merely to summarize usage unless the user explicitly enables that feature.

Default analysis should be deterministic and free:

* Statistical comparison
* Context growth
* Token ratios
* Tool-call frequency
* Session length
* Model changes
* Cache behavior
* Subagent usage
* Project attribution

Optional AI analysis can later support:

* Bring your own API key
* Local model analysis
* Explicit opt-in hosted analysis

⸻

4. SessionWatcher-style authentication

SessionWatcher-style login is technically feasible, but there are several distinct authentication methods.

4.1 Authentication methods

Official OAuth or device authorization

The preferred method.

The user authenticates directly on the provider’s domain, and the app receives a scoped authorization token.

Advantages:

* Provider-controlled authentication
* No password handling
* Clear permission scopes
* Better commercial suitability
* Easier revocation

Reuse of existing CLI credentials

The app detects that the official provider CLI is already authenticated and uses that login indirectly.

Examples:

* Codex CLI ChatGPT authentication
* Claude Code authentication
* GitHub CLI or Copilot CLI authorization

The app should ideally invoke the CLI or provider-owned helper rather than directly copying credentials.

Authenticated browser session

The app opens the provider’s login page and uses the resulting authenticated session to retrieve account data.

This may involve undocumented dashboard endpoints or browser session state.

This approach is:

* Feasible for personal use
* Potentially accurate
* More fragile
* More difficult to commercialize
* More likely to break after provider changes
* More sensitive from a security perspective

It should be treated as an experimental fallback, not the primary foundation.

⸻

5. Does authentication or usage retrieval incur a fee?

Authentication itself does not normally cost money.

Reading account usage, quota, billing, or reset metadata also does not normally consume model tokens.

No expected additional fee

* Signing into Claude, OpenAI, or GitHub
* Running a login-status command
* Reading local logs
* Running ccusage
* Fetching usage metadata
* Fetching billing metadata
* Refreshing OAuth tokens
* Reading reset timestamps
* Reading CloudKit snapshots

Possible costs

Costs can occur when:

* A provider API key is used to generate model output
* The app runs a test prompt to check connectivity
* AI-generated analysis is enabled
* A proprietary backend is introduced
* CloudKit or infrastructure usage becomes very large
* A third-party service is added
* The provider later monetizes a currently free metadata endpoint

Rate limiting is not the same as billing. A provider may limit how frequently usage data can be retrieved without charging for the request.

⸻

6. Provider integration plan

6.1 OpenAI Codex

Recommended approach

1. Detect whether Codex is installed.
2. Run codex login status.
3. Detect the current authentication method.
4. Read locally available Codex history.
5. Retrieve actual quota through supported CLI or status mechanisms.
6. Use the authenticated usage dashboard only as a fallback.
7. Ask the user to run codex login only when Codex is not authenticated.

Do not display, copy, or synchronize the contents of ~/.codex/auth.json.

Prefer invoking Codex as a subprocess and allowing Codex to manage its own credentials.

Implemented native connection contract:

* The menu has a dedicated connection stage when `account/read` does not confirm an account; cached quota content is not mixed into that stage.
* The stage offers **Sign in with browser** and **Sign in with Codex CLI…**, followed by **Settings…** and **Quit Codex Usage Monitor** at the bottom.
* Browser sign-in sends `account/login/start` with `type: chatgpt`, opens only the provider-created HTTPS URL, keeps the app-server session alive for the matching completion event, and confirms the account with a fresh `account/read`.
* CLI sign-in visibly opens Terminal and executes the located `codex login`, while the app polls `codex login status` and confirms success with `account/read`.
* Checking, missing CLI, disconnected, signing in, connected, and recoverable failure are provider-neutral UI states that future agent integrations can map to without exposing provider errors or credentials.
* A confirmed sign-in triggers one quota refresh with the `authentication` refresh reason. Logout and account switching remain out of scope.

Source priority

Supported structured CLI quota output
→ Official Codex status mechanism
→ Supported local account state
→ Authenticated usage dashboard
→ Local usage calculation
→ Cached snapshot

Cost expectations

Operation	Expected added fee
codex login status	None
Reading local logs	None
Fetching quota metadata	None expected
Using Codex through ChatGPT login	Uses included plan limits
Using Codex through an API key	Standard API charges
LLM-generated usage analysis	API charge unless local or BYOK

Codex-specific metrics

* Short-term limit
* Weekly limit
* Reset times
* Model usage
* Token usage
* Session duration
* Project usage
* Tool-call activity
* Context growth
* Reasoning or effort level where observable
* Local versus official usage discrepancy

⸻

6.2 GitHub Copilot Student

Initial authentication

For the personal version:

1. User creates a fine-grained personal access token.
2. Token receives only the minimum required read permission.
3. Token is stored in macOS Keychain.
4. App retrieves personal Copilot billing or allowance data.
5. App compares provider data against local CLI or editor observations.

For a public version, replace token setup with GitHub OAuth or GitHub App authorization.

Supported allowance types

The data model should not assume a single Copilot billing system.

enum CopilotAllowance {
    case aiCredits
    case premiumRequests
    case chatAllowance
    case agentAllowance
    case unlimitedCompletions
    case meteredOverage
}

Copilot-specific metrics

* AI credits used
* AI credits remaining
* Monthly reset date
* Premium requests for legacy users
* Chat requests
* Agent requests
* CLI usage
* Model breakdown where available
* Included versus paid usage
* Local versus account-level discrepancy

Cost expectations

Fetching account billing or allowance information should not consume Copilot requests.

Potential limitations include:

* GitHub API rate limits
* Student entitlement reporting differences
* Billing-platform transitions
* Endpoint changes
* Organization-managed versus personal allowances

⸻

6.3 Claude Code

Local analytics

Use:

* Claude Code JSONL history
* ccusage or compatible parsing
* Claude CLI output where available
* Session blocks
* Local reset information
* Model and project attribution
* Tool and skill activity

This should provide:

* Tokens
* Models
* Projects
* Sessions
* Five-hour blocks
* Daily, weekly, and monthly history
* Cache behavior
* API-equivalent cost
* Usage velocity
* Context growth
* Tool and skill attribution

Actual provider quota

Preferred order:

Claude CLI-supported usage data
→ Existing Claude credential used indirectly through Claude
→ Provider-reported usage command
→ Authenticated Claude dashboard
→ Local calculation
→ Cached value

Login-based connection

The app may provide a Connect Claude account option.

The login page must be provider-controlled. The app must never request a Claude password through its own form.

The app should not:

* Store the user’s password
* Ask the user to paste raw cookies
* Upload Claude credentials to CloudKit
* Synchronize credential files
* Present experimental dashboard integration as officially supported

Cost expectations

* Reading local Claude logs: no fee
* Running ccusage: no fee
* Fetching account metadata: no expected model charge
* Claude API analysis: standard API fee
* Local or deterministic analysis: no provider fee

⸻

7. Authentication architecture

Connection method

enum ConnectionMethod: Codable {
    case existingCLI
    case officialOAuth
    case deviceAuthorization
    case personalAccessToken
    case localFilesOnly
    case authenticatedDashboard
    case experimentalWebSession
}

Connection state

enum ConnectionState {
    case notInstalled
    case disconnected
    case connecting
    case connected(ConnectionMethod)
    case partialAccess
    case expired
    case permissionDenied
    case rateLimited
    case unsupported
    case error
}

Authentication screen

Connections
Claude Code
● Local analytics connected
Quota source: Claude CLI
Authority: Official CLI
Last verified: 2 minutes ago
[Refresh] [Reconnect] [Details]
Codex
● Using existing ChatGPT login
Quota source: Codex CLI
Authority: Official CLI
Last verified: 1 minute ago
[Refresh] [Open Codex Login]
GitHub Copilot
● GitHub account connected
Plan: Copilot Student
Allowance: AI Credits
Authority: Official API
[Refresh] [Reconnect]

For every connection, show:

* Authentication method
* Requested permission
* Data being accessed
* Credential-storage location
* Whether the source is official
* Whether requests may incur charges
* Last successful authentication
* Last successful quota fetch
* Revocation instructions

⸻

8. Menu-bar interface

8.1 Compact menu-bar states

User-selectable display modes:

* Lowest remaining provider
* Active provider
* Claude only
* Codex only
* Copilot only
* Next reset countdown
* Combined compact values
* Icon only

Examples:

Claude 24%
C 24 · O 71 · G 82
24% · 1h 18m

8.2 Main popover

Each provider card should display:

* Provider name
* Account or plan
* Current remaining quota
* Used quota
* Multiple quota windows
* Reset countdown
* Absolute reset time
* Forecasted exhaustion
* Recent usage velocity
* Model breakdown
* Active project
* Current session
* Tool and skill contribution
* Data authority
* Last refresh
* Connection health

Example:

Claude Code                                      24%
5-hour window
███████████████░░░░░  76% used
Resets in 1h 18m
Weekly window
████████░░░░░░░░░░░░  42% used
Resets Monday at 8:00 PM
Projected exhaustion
43 minutes at current rate
Recent usage increase
+38% over previous hour
Likely contributors
• Context grew from 42K to 118K tokens
• 4 Explore subagents were launched
• Browser automation skill used 17 times
• Cache-read ratio declined from 71% to 38%
Source: Official Claude quota + local analytics
Updated 22 seconds ago

⸻

9. Notifications and warnings

9.1 Remaining-limit thresholds

Default alerts:

* 50% remaining: optional informational alert
* 25% remaining: warning
* 10% remaining: urgent warning
* 5% remaining: critical warning
* Limit exhausted: critical notification
* Limit reset: informational notification

Recommended defaults:

Threshold	Default
50% remaining	Off
25% remaining	On
10% remaining	On
5% remaining	On
Exhausted	On
Reset completed	On

Example:

Claude is below 25%
24% of the current five-hour allowance remains.
At your current rate, it may run out in 41 minutes.
The limit resets in 1 hour 18 minutes.

9.2 Forecast alerts

Notify before a threshold is reached when the forecast predicts exhaustion.

Examples:

* Projected to hit 25% within 20 minutes
* Projected to exhaust before reset
* Current session is using quota at 2.4× normal rate
* Weekly usage is ahead of sustainable pace
* Current model is consuming allowance faster than usual

9.3 Reset reminders

Support reminders:

* 60 minutes before reset
* 30 minutes before reset
* 10 minutes before reset
* At reset
* A configurable time after reset to verify that quota refreshed

Example:

Claude resets in 10 minutes
You currently have 6% remaining.
Pause large tasks or switch providers until the reset.

9.4 Reset verification

After the expected reset time:

1. Refresh the provider.
2. Confirm that the quota actually increased.
3. Notify the user if it did.
4. Warn if the value did not refresh.
5. Retry according to backoff settings.

Example:

Codex limit did not refresh as expected
The reset was scheduled for 8:00 PM, but the provider still reports
the previous usage level. The app will retry in 5 minutes.

9.5 Sudden-change alerts

Notify when:

* Usage rises unusually quickly
* Quota drops without corresponding local activity
* Usage changes on another device
* A provider changes the reset timestamp
* A weekly limit appears unexpectedly
* Paid overage begins
* A new model-specific limit appears
* Official and local values diverge significantly

9.6 Notification controls

Users should be able to configure:

* Thresholds per provider
* Thresholds per window
* Notification sounds
* Critical alerts
* Quiet hours
* Snooze duration
* Repeat frequency
* Whether alerts repeat until acknowledged
* Whether alerts appear on Watch
* Whether usage analysis is included in the notification
* Whether provider-switch recommendations are shown

⸻

10. Refresh behavior

10.1 Refresh methods

Support:

* Manual refresh
* Refresh when the menu opens
* Refresh when the app becomes active
* Scheduled foreground refresh while the menu-bar process is running
* Refresh after local log changes
* Refresh near a reset
* Refresh after authentication changes
* Refresh after waking from sleep
* Refresh when network connectivity returns

10.2 User-selectable refresh intervals

Options:

* 1 minute
* 1 minute 30 seconds
* 2 minutes
* 5 minutes
* 10 minutes
* Adaptive

Current default: 2 minutes.

10.3 Adaptive refresh policy

Steady usage                     every 5 minutes
At or below 50% remaining        every 2 minutes
At or below 25% remaining        every 90 seconds
At or below 10% remaining        every 1 minute
Imminent threshold/exhaustion    every 30 seconds, at most 10 minutes
Within 10 minutes of reset       every 30 seconds, at most 10 minutes
First two refresh failures       current Automatic backoff: every 5 minutes; fixed modes unchanged
Third refresh failure onward     one alert on the third failure, then retry every 10 minutes
Computer asleep                  no refresh
Offline                          use cache
Launch or wake                   immediate refresh

10.4 Refresh limits and safety

The app should enforce minimum polling intervals for provider endpoints.

Example:

Provider minimum: 60 seconds
Widget minimum: cached snapshot only
Failed authentication: stop automatic retries after 3 attempts
Rate limit: honor provider retry headers

10.5 Refresh status

Display:

* Last attempted refresh
* Last successful refresh
* Next scheduled refresh
* Current refresh interval
* Rate-limit status
* Whether the value came from cache
* Whether background refresh is paused

⸻

11. Refresh reminders and stale-data handling

11.1 Stale-data thresholds

Suggested defaults:

* Fresh: under 5 minutes
* Aging: 5–15 minutes
* Stale: 15–60 minutes
* Very stale: over 60 minutes

11.2 Stale-data warnings

Examples:

Claude data is 22 minutes old
The previous refresh failed because the Claude CLI session expired.
Reconnect to restore official quota updates.
Copilot usage has not refreshed today
The GitHub token may be missing the required Plan read permission.

11.3 Refresh reminder options

Users may enable reminders when:

* A provider has not refreshed for 15 minutes
* A provider has not refreshed for one hour
* A provider has not refreshed since launch
* Authentication has expired
* CloudKit has not synchronized recently
* Watch data is stale
* A quota reset could not be verified

⸻

12. Usage-change analysis

The app should explain why usage increased without reading or uploading prompt contents.

12.1 Deterministic attribution categories

Context growth

Detect:

* Large growth in conversation context
* Repeated inclusion of repository files
* Large tool outputs
* Long terminal output
* Repeated context reconstruction
* Compaction events
* Sessions continuing beyond efficient context size

Example:

Context growth likely caused most of the increase.
The active session grew from 38K to 126K input tokens.
Input-token use increased 3.1× while output-token use remained stable.

Tool use

Detect usage associated with:

* Shell commands
* File reads
* File writes
* Search tools
* Browser automation
* Web retrieval
* Test runs
* Build commands
* Large command output
* Image or multimodal processing

Example:

Tool output contributed to the increase.
Eight terminal commands returned more than 20K characters each.
Tool-result tokens accounted for approximately 46% of the session.

Skill or agent use

Where observable, track:

* Skills invoked
* Slash commands
* MCP servers
* Subagents
* Explore agents
* Planning agents
* Code-review agents
* Browser agents
* Custom instructions
* Project skills
* Global skills

Example:

Subagent activity was the main contributor.
Four Explore agents ran during the last hour and accounted for
approximately 39% of locally observed token use.

Model changes

Detect:

* Switching to a more expensive model
* Increased reasoning effort
* Increased maximum output
* Use of a premium model
* Different provider multiplier behavior

Example:

Usage accelerated after switching models.
The active session changed from Sonnet to Opus.
Token volume changed only slightly, but quota consumption increased faster.

Cache behavior

Detect:

* Cache read percentage falling
* Cache creation increasing
* Cache invalidation
* Repeated uncached context
* New sessions losing reusable context

Example:

Reduced cache reuse likely increased consumption.
Cache-read coverage fell from 74% to 32% after the project context changed.

Project behavior

Detect:

* New project loaded
* Large repository
* Multiple repositories in one session
* Generated files or dependencies being scanned
* Repeated full-codebase searches
* Large lockfiles or build artifacts entering context

Cross-device discrepancy

When official quota falls without matching local activity:

Official Claude usage dropped by 14%, but this Mac recorded little activity.
Possible causes:
• Usage on another device
• Claude web or mobile usage
• Remote agent activity
• Delayed provider accounting

12.2 Analysis confidence

Each explanation should include confidence:

* High confidence
* Moderate confidence
* Low confidence
* Insufficient data

Do not claim exact causation when only correlation is available.

Example:

Likely cause: context growth
Confidence: High
Input tokens increased by 212% while output tokens and tool calls remained stable.

12.3 Usage comparison periods

Support comparisons against:

* Previous 15 minutes
* Previous hour
* Previous session
* Previous day
* Seven-day average
* Same weekday
* Same project
* Same model
* Same skill
* Same agent type

⸻

13. Historical analytics

Track:

* Input tokens
* Output tokens
* Cache creation tokens
* Cache read tokens
* Requests
* Sessions
* Session duration
* Active time
* Idle time
* Subagent usage
* Tool calls
* Skill invocations
* Models
* Providers
* Projects
* Daily totals
* Weekly totals
* Monthly totals
* Estimated API-equivalent cost
* Subscription-equivalent value
* Quota consumption
* Reset events
* Usage immediately before and after reset
* Official versus local discrepancy
* Forecast accuracy

Views

* Today
* Current quota window
* Last 24 hours
* Seven days
* Thirty days
* Current billing period
* Custom range

Breakdowns

* By provider
* By model
* By project
* By session
* By agent
* By skill
* By tool
* By token type
* By quota window

⸻

14. Forecasting and recommendations

14.1 Deterministic forecasting

remaining quota
÷ recent quota-consumption rate
= estimated time to exhaustion

Use multiple velocity models:

* 15-minute velocity
* One-hour velocity
* Current-session velocity
* Seven-day average
* Same-project average
* Same-model average
* Same-day-of-week average

14.2 Forecast confidence

Confidence should depend on:

* Number of samples
* Stability of recent usage
* Age of provider data
* Authority of the quota source
* Whether usage occurred on other devices
* Whether model multipliers are known

14.3 Provider recommendation

Example:

Recommended provider: Codex
Claude is projected to reach its session limit in 34 minutes.
Codex has 78% of its current allowance remaining.
Copilot has 12 AI credits remaining this month.

The recommendation must be based only on usage availability unless the user later chooses to include quality, model, or project preferences.

14.4 Pace guidance

Examples:

To avoid exhausting Claude before its reset, keep usage below
approximately 8% per hour for the next 3 hours.
Your weekly Codex usage is 18% ahead of a sustainable pace.

⸻

15. Widgets

15.1 macOS small widget

Display:

* Selected provider
* Remaining percentage
* Reset countdown
* Stale-data indicator

15.2 macOS medium widget

Display all providers:

Claude      24%      1h 18m
Codex       71%      Monday
Copilot     82%      August 1

15.3 macOS large widget

Display:

* All providers
* Current forecast
* Recent usage trend
* Next reset
* Most significant warning
* Last updated time

15.4 Widget configuration

Allow the user to select:

* Provider
* Quota window
* Remaining versus used
* Percentage versus units
* Reset countdown
* Forecast
* Lowest-limit mode
* Privacy mode
* Refresh freshness indicator

Widget architecture

Provider collectors
        ↓
Normalized local database
        ↓
Sanitized App Group snapshot
        ↓
WidgetKit extension

Widgets must never invoke provider CLIs or access credentials directly.

⸻

16. CloudKit and Apple Watch

16.1 CloudKit data

CloudKit should contain only:

* Provider identifier
* Remaining percentage
* Used units
* Limit units
* Reset timestamp
* Forecasted exhaustion
* Data authority
* Confidence
* Last updated timestamp
* Warning state

16.2 Local-only data

Do not sync:

* Credentials
* Raw logs
* Prompt contents
* Responses
* Full project paths
* Session transcripts
* Browser cookies
* CLI configuration
* Tool inputs
* Tool outputs

16.3 Watch complication

Initial Watch support should be complication-first, not a full watch application.

Circular

C
24%

Rectangular

Claude 24%
Resets in 1h 18m

Inline

Claude 24% · 1h

Lowest-limit mode

Automatically show whichever provider has the least remaining capacity.

Warning state

At 50%, 25%, 10%, and 5%, the complication may display an alert symbol or urgency state, while respecting Apple’s complication design constraints.

⸻

17. Normalized data model

struct ProviderUsageSnapshot: Codable, Identifiable {
    let id: UUID
    let provider: Provider
    let accountIdentifier: String?
    let plan: String?
    let windows: [UsageWindow]
    let localUsage: LocalUsageSummary?
    let source: UsageDataSource
    let confidence: ConfidenceLevel
    let connectionState: ConnectionState
    let collectedAt: Date
    let expiresAt: Date?
    let nextRefreshAt: Date?
    let diagnostics: [Diagnostic]
}
struct UsageWindow: Codable {
    let identifier: String
    let displayName: String
    let used: Decimal?
    let limit: Decimal?
    let remainingFraction: Double?
    let resetAt: Date?
    let unit: UsageUnit
    let authority: DataAuthority
}
struct UsageAnalysis: Codable {
    let period: DateInterval
    let changePercent: Double
    let likelyCauses: [UsageCause]
    let confidence: ConfidenceLevel
    let supportingMetrics: [MetricEvidence]
}
enum UsageCause: Codable {
    case contextGrowth
    case modelChange
    case skillInvocation
    case subagentActivity
    case toolOutput
    case cacheMiss
    case projectChange
    case longSession
    case externalDeviceUsage
    case unknown
}

⸻

18. Development phases

Current execution status (2026-07-13)

* The Codex capability probe, menu-bar MVP, and quota-history foundation are implemented.
* Reliability-hardening Tasks 1–4 are implemented; compilation is verified without adding or running tests.
* The seven-calendar-day reliability observation in `docs/superpowers/plans/2026-07-13-codex-reliability-hardening.md` remains required before release, but Codex-only feature work may proceed while it accumulates evidence.
* Do not begin another provider integration until the reliability gate records refresh outcomes, foreground-independent cadence, forecast behavior, and a Codex-adapter decision.
* The Codex-first daily-driver roadmap is recorded in `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`.
* `feature/notification-settings` is implemented with persisted category controls and operational reset/stale/failure warnings; the app-owned quiet-hours feature was retired in favor of macOS Focus and notification settings. Interruption backoff is implemented, with one delivery-retry durability follow-up and controlled outage acceptance still open.
* `feature/settings-foundation` is implemented with targeted manual acceptance pending. It adds General, Refresh, Agents, Data & Privacy, and Diagnostics tabs around Notifications, using only real actions and privacy-safe read-only status. General, Notifications, Refresh, and Agents use lower-content sidebars; Codex is current while Claude Code and GitHub Copilot remain visibly planned and not connected.
* `feature/adaptive-refresh` is implemented. It replaces the repeating five-minute timer with persisted fixed/automatic modes, a one-shot scheduler, a snapshotted native-menu countdown, and monitor-owned confirmed/completed or cached/paused display state. The snapshot currently creates a known presentation regression: an already-open menu can retain `Refreshing…` or a frozen relative countdown. The planned event-driven absolute-time repair must also preserve the fixed scrolling/highlight geometry below Quit. Settings mode switching and a natural cached/paused state remain targeted manual checks.
* `feature/codex-connection` is implemented and user-accepted. Browser and visible CLI sign-in, disconnected presentation, and return to quota refresh work without reading credentials; acceptance is not repeated by signing out the user's active account.
* `feature/settings-ui-followups` is implemented with targeted manual acceptance pending. It replaces the combined quota-threshold switch with independent 50%, 25%, 10%, and 5% choices for both five-hour and weekly lanes. Turning off the notification master switch greys all subordinate controls without erasing their selections, while authorization recovery remains usable.
* The same Settings follow-up branch adds General controls for Launch at Login, System/Light/Dark appearance, and app-local keyboard-shortcut enablement. The July 16 fix keeps one Settings presentation owner and resolves System from live macOS effective appearance, eliminating the reproduced Light → System/System-Dark mixed window without recoloring the native menu. Reciprocal System-Light and manufactured conditional-state acceptance remain recorded in `2026-07-15-settings-system-appearance-transition.md`. Launch at Login acceptance was skipped for this pass. Initial custom shortcut scope is Command-R for Refresh; standard Command-, and Command-Q remain available.
* Agents is selected from the global Settings sidebar and displays Codex, Claude Code, and GitHub Copilot as grouped sections on one scrollable page. Codex retains its current connection and sign-in actions; the other providers remain visibly planned and do not collect data.
* `feature/notification-settings` is merged with persisted category controls and operational reset/stale/failure warnings; the app-owned quiet-hours feature was retired in favor of macOS Focus and notification scheduling.
* `feature/settings-foundation` is active. It adds General, Refresh, Agents, Data & Privacy, and Diagnostics tabs around the existing Notifications tab, using only real actions and privacy-safe read-only status. Agents uses a left provider sidebar with an in-tab detail pane for each agent; Codex is current while Claude Code and GitHub Copilot remain visibly planned and not connected.
* `feature/adaptive-refresh` is active as a stacked branch on `feature/settings-foundation`. It replaces the repeating five-minute timer with persisted fixed/automatic modes, a one-shot scheduler, a next-refresh countdown, and monitor-owned confirmed/completed or cached/paused display state.
* `feature/settings-ui-followups` is implemented with manual UI acceptance pending as a stacked branch on `feature/menu-bar-display`. It replaces the combined quota-threshold switch with independent 50%, 25%, 10%, and 5% choices for both five-hour and weekly lanes. Turning off the notification master switch greys all subordinate controls without erasing their selections, while authorization recovery remains usable.
* The same Settings follow-up branch adds working General controls for Launch at Login, System/Light/Dark appearance, and app-local keyboard-shortcut enablement. Initial custom shortcut scope is Command-R for Refresh; standard Command-, and Command-Q remain available.
* The Agents tab keeps the full-width top Settings tab bar unchanged. Its provider list appears in an inner 180-point sidebar that begins below the tab bar and divides only the lower Agents content region. Compilation, signed-bundle validation, and launch survival passed; visual interaction and persistence checks remain manual.
* All UI work must use a shared two-state quota presentation contract: confirmed/completed after a trusted live refresh, or cached/paused after an unsuccessful refresh while retaining and labeling the last confirmed record.
* `feature/menu-bar-display` is implemented with manual UI acceptance pending as a stacked branch on `feature/codex-connection`. It adds a Menu Bar section to General: **Appearance** switches between the current gauge and a dual-limit label formatted as `5H: 64% | Week: 82%`; **Show** switches all percentages between Remaining and Used, with Remaining as the default. The label observes the existing configured refresh schedule rather than starting another timer. Missing lanes display `—`, and cached/paused values retain a visible pause marker instead of falling back to a misleading `0%`. Compilation, signed-bundle validation, and new-instance process survival passed; visual switching, preference relaunch, and a scheduled interval remain manual checks. Other compact styles remain later extensions.
* A separate frontend-only `feature/figma-ui-overhaul` branch is planned after the functional UI branches stabilize. It will import approved Figma nodes into Settings and Dashboard using Figma MCP, preserve native menu semantics, and leave collection, scheduling, authentication, notification, and storage behavior unchanged.

Phase 0 — Provider capability research

Create a command-line research harness.

Claude

* Locate JSONL files
* Run ccusage JSON reports
* Compare local totals with Claude’s displayed usage
* Identify supported CLI quota mechanisms
* Test actual quota retrieval
* Determine whether CLI credentials can be used indirectly
* Test reset timestamps
* Record sample responses
* Inspect tool and skill observability
* Inspect subagent attribution
* Measure context-growth signals

Codex

* Run codex login status
* Inspect supported local files
* Test /status
* Test noninteractive quota retrieval
* Compare local usage with official dashboard values
* Determine refresh behavior
* Determine reset-window structure
* Inspect model and tool attribution

Copilot Student

* Create a minimal-permission token
* Test user-level billing or allowance APIs
* Confirm Student-plan response format
* Compare API values with GitHub and editor displays
* Test CLI usage
* Confirm reset timing
* Determine whether requests can be attributed by model or surface

Exit criteria

* Every probed capability is classified as supported, experimental, local-only, or unavailable
* At least one provider returns provider-reported quota or allowance data
* Claude and Codex return meaningful local analytics
* No collector requires a password, raw-cookie pasting, or a model turn
* Available reset timestamps and quota windows are recorded without inventing missing values
* Observed refresh constraints and failure modes are documented
* Sanitized sample fixtures are stored
* Available data can be normalized without erasing source, freshness, or uncertainty

⸻

Phase 1 — macOS personal MVP

Build:

* Menu-bar application
* Launch at login
* Provider connection screen
* Keychain integration
* Claude local collector
* Codex local collector
* GitHub connection
* SwiftData or SQLite storage
* Current quota display only where provider-reported data is available
* Reset countdown only where a reset timestamp is available
* Manual refresh
* Scheduled refresh
* Source and confidence labels
* Stale-data states
* 50%, 25%, 10%, and 5% notifications for provider-reported values
* Reset notifications for verified reset timestamps
* JSON and CSV export
* Diagnostics screen

⸻

Phase 2 — provider quota integration

Build:

* Codex quota adapter, labeled experimental unless a documented personal interface is available
* GitHub authoritative allowance adapter
* Claude quota adapter, labeled experimental unless a documented personal interface is available
* Optional Claude authenticated-dashboard experiment
* Multiple quota windows
* Reset verification
* Authentication-expiry detection
* Rate-limit handling
* Retry and backoff
* Official versus local discrepancy tracking
* Last-known-good snapshots

⸻

Phase 3 — usage analysis

Build:

* Context-growth detection
* Tool-output attribution
* Skill attribution
* Agent and subagent attribution
* Model-change detection
* Cache-efficiency analysis
* Project-change detection
* Cross-device discrepancy detection
* Usage anomaly detection
* Confidence scoring
* “Why did usage increase?” explanations
* Usage-change notifications

⸻

Phase 4 — forecasting and advanced alerts

Build:

* Time-to-exhaustion forecast
* Sustainable pace calculation
* Weekly pace forecast
* Forecasted threshold alerts
* Provider-switch recommendations
* Reset reminders
* Failed-reset verification
* Custom threshold editor
* Quiet hours
* Alert snoozing
* Per-provider alert rules

⸻

Phase 5 — macOS widgets

Build:

* App Group snapshot store
* Small widget
* Medium widget
* Large widget
* Widget configuration
* Lowest-limit mode
* Deep links
* Staleness display
* Reset-aware timelines
* Privacy mode

⸻

Phase 6 — CloudKit and Watch complication

Build:

* Private CloudKit schema
* Sanitized snapshot sync
* Conflict resolution
* Sync diagnostics
* iPhone WidgetKit target
* Watch complication target
* Lowest-limit complication
* Watch warning state
* Stale Watch-data handling

⸻

Phase 7 — evaluate commercial release

Consider:

* Replacing external parsers with bundled or native implementations
* Replacing personal tokens with OAuth
* Improving onboarding
* Adding signed automatic updates
* Adding Mac App Store compatibility
* Adding more providers
* Adding team features
* Adding paid analytics
* Adding optional BYOK AI analysis
* Adding self-hosted synchronization
* Reviewing all dependency licenses
* Reviewing provider terms and authentication policies

⸻

19. First implementation milestone

The first milestone should be a provider capability probe rather than a polished UI.

UsageProbe/
├── Sources/
│   ├── ClaudeProbe/
│   ├── CodexProbe/
│   └── GitHubProbe/
├── Fixtures/
│   ├── Claude/
│   ├── Codex/
│   └── Copilot/
├── Outputs/
├── Findings/
│   ├── claude.md
│   ├── codex.md
│   ├── copilot.md
│   └── provider-matrix.md
└── normalized-schema.json

Example normalized output:

{
  "provider": "claude",
  "plan": "max",
  "windows": [
    {
      "id": "five-hour",
      "used": 76,
      "limit": 100,
      "remainingFraction": 0.24,
      "resetAt": "2026-07-11T09:20:00Z",
      "authority": "official-cli"
    }
  ],
  "localUsage": {
    "inputTokens": 1042000,
    "outputTokens": 184000,
    "cacheReadTokens": 772000,
    "estimatedApiCost": 14.72
  },
  "analysis": {
    "changePercent": 38,
    "likelyCauses": [
      {
        "cause": "context-growth",
        "confidence": "high"
      },
      {
        "cause": "subagent-activity",
        "confidence": "moderate"
      }
    ]
  },
  "collectedAt": "2026-07-11T08:02:00Z"
}

⸻

20. Recommended initial connection strategy

Provider	Initial method
Claude	Existing Claude CLI authentication plus ccusage/local analytics
Codex	Existing Codex CLI ChatGPT authentication
GitHub Copilot Student	Fine-grained GitHub token with minimum read permission
CloudKit	User’s existing iCloud account

This approach avoids duplicate passwords, keeps operating costs close to zero, provides provider-reported quota where a probe validates it, and preserves detailed local analytics without introducing a proprietary backend.

The first major technical objective should be proving reliable authoritative quota retrieval. The first major product objective should be making the data actionable through warnings, reset reminders, forecasting, and understandable explanations of usage increases.
