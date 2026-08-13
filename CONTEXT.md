# Codex Usage Monitor UI

Canonical language for discussing the app's user-interface regions and interactions. These definitions keep design plans, implementation discussions, and visual acceptance aligned.

## Settings Regions

**Settings Window**:
The outer macOS window containing the Navigation Sidebar, Settings Page, and optional Context Rail. It widens only to the right when the Context Rail becomes Visible and shrinks by the same allocation when it becomes Hidden.
_Avoid_: Settings container, overall settings

**Navigation Sidebar**:
The persistent left Settings region containing search and the destination navigation. It does not collapse or change when the Context Rail changes visibility.
_Avoid_: Left sidebar, navigation pane

**Settings Page**:
The fixed center Settings region containing the sections and controls for the selected destination. Its frame remains unchanged when either surrounding rail changes state.
_Avoid_: Middle portion, middle pane, detail pane

**Settings Page Header**:
The fixed top row of the Settings Page containing the destination identity or agent selector and the Context Rail Toggle.
_Avoid_: Top bar, middle top bar, window toolbar

**Context Rail Toggle**:
The persistent trailing control in the Settings Page Header that changes the Context Rail between Hidden and Visible.
_Avoid_: Expand button, sidebar button, preview button

**Context Rail**:
The optional right Settings region containing previews, summaries, and contextual status. It is Hidden by default, its visibility is not persisted, and it may become Visible without changing the Navigation Sidebar or Settings Page.
_Avoid_: Right sidebar, preview sidebar, context panel, collapsed rail, expanded rail

## Settings Navigation

**Settings Destination**:
A top-level Settings category selected from the Navigation Sidebar, such as General or Notifications.
_Avoid_: Tab, top tab, navigation item

**Menu Bar Settings Destination**:
The planned Settings Destination that will own Menu Bar Agent and presentation controls once the menu-bar option set expands beyond the current General section.
_Avoid_: Menu Bar tab, General Menu Bar section after migration

**Settings Section**:
A titled group of related controls or information within a Settings Page, such as Appearance or Weekly Quota.
_Avoid_: Subtab, element, subsection page

**Settings Search Index**:
The static metadata catalog of every actionable or settable control that Settings search can find, independent of whether its view is currently rendered.
_Avoid_: View scraping, live text index, rendered-text search

**Searchable Setting**:
One indexed actionable control, identified by stable setting, destination, and section identities plus title, synonyms, and keywords.
_Avoid_: Searchable row text, indexed status value

**Settings Search Result**:
A ranked match for one Searchable Setting. Selecting it opens the correct Settings Destination and brings the exact control into view.
_Avoid_: Filter result, search suggestion, section result

**Settings Search Results**:
The temporary flat list, grouped by Settings Destination, that replaces normal Navigation Sidebar destinations while a query is active. Each result identifies its setting and parent destination; selecting one clears the query and restores normal navigation.
_Avoid_: Filtered navigation, extra destinations

**Search-First Focus**:
The Settings keyboard behavior in which search is ready when the window opens and unmodified printable typing starts a query. It does not steal focus from active controls or text capture, command shortcuts remain commands rather than search text, and Escape clears a query without dismissing Settings.
_Avoid_: Permanent first responder, global text capture

**Setting Focus Cue**:
A brief, restrained animation that identifies the exact actionable control reached from a Settings Search Result.
_Avoid_: Section focus, flash, selection state, permanent highlight

## Settings Controls

**Settings Design Language**:
The app's native macOS Settings appearance built from system typography, semantic colors, shared spacing, grouped cards, SF Symbols, and native controls.
_Avoid_: Custom theme, web styling, Figma runtime

**Preference Switch**:
A native switch that enables or disables one independent setting or warning. Current Boolean preferences use Preference Switches, including individual quota thresholds.
_Avoid_: Checkbox, tick box, toggle button

**Checkbox**:
A control reserved for selecting items for a future batch action, not for enabling an independent preference.
_Avoid_: Preference switch, on/off setting

**Action Control**:
A button that performs a one-time operation, such as Refresh Now, Connect, Disconnect, or opening macOS settings. Action Controls are searchable, but selecting their Settings Search Result only navigates to them and never executes them.
_Avoid_: Setting, preference, search action

**Quota Window Selector**:
The native two-segment control inside an Agent Settings Page's Usage Warnings section that chooses whether five-hour or weekly Window Warning Settings are shown. It defaults to five-hour, remembers its choice only for the current Settings Window session, and is not persisted.
_Avoid_: Quota tabs, sub-tabs, timeframe picker

**Menu Bar Agent Selector**:
The persisted native control that chooses the Preferred Menu Bar Agent from Connected Agents, including agents whose monitoring is inactive.
_Avoid_: Settings Agent selector, active-agent selector, provider filter

**Menu Bar Failover Policy**:
The persisted Single-Agent Menu Bar Mode choice governing connection loss: Stay Selected keeps the Preferred Menu Bar Agent effective while showing its disconnected state, while Switch Automatically temporarily chooses another Connected Agent. Stay Selected is the default.
_Avoid_: Disconnect toggle, fallback agent, active-agent switching

**Command Shortcut**:
The key equivalent for one menu popover footer command, shown right-aligned on its row and listed in General's Startup & Shortcuts section. Display and binding come from one catalog, so a listed shortcut is always the one that fires. Enable keyboard shortcuts governs both: with it off, nothing is shown and nothing is bound. The assignments are fixed; editing them is deferred.
_Avoid_: Hotkey, global shortcut, accelerator

**Menu Bar Glyph**:
The provider mark drawn beside the menu bar's text label, shown only when more than one agent is eligible. It renders as a template, so its artwork is monochrome with transparent knockouts and is named separately from the colored artwork used on Settings tiles.
_Avoid_: Provider icon, menu bar logo, status icon

## Usage Warnings

**Shared Refresh Cadence**:
The initial multi-agent scheduling model in which one app-wide Refresh preference triggers independent, parallel refreshes for every Active Agent. Per-agent frequencies are deferred, and one provider's outcome does not block another's.
_Avoid_: Per-agent schedule, synchronized result, provider cadence

**Refresh Outcome**:
The trust result of one provider refresh: Confirmed, Confirmed After Retry, Cached, Unconfirmed, or Unavailable. It describes what data state resulted, not why.
_Avoid_: Failure cause, network state, error message

**Refresh Failure Classification**:
An evidence-based explanation for an Unconfirmed or Unavailable Refresh Outcome, kept separate from the outcome itself. The detailed taxonomy remains provisional; network and provider-compatibility labels must use cautious, supportable evidence.
_Avoid_: Refresh outcome, raw error text, assumed outage cause

**Usage Notification Identity**:
The provider and Quota Window named explicitly in a usage notification's title and body, paired with the Codex Usage Monitor application icon. Quota warning copy always uses remaining-quota language; provider-specific artwork is optional and requires separately approved assets and platform validation.
_Avoid_: Unofficial provider icon, color-only identity, generic quota warning

**Supported Agent**:
An agent provider for which the app has a working integration rather than roadmap-only representation.
_Avoid_: Planned agent, listed agent, available enum case

**Provider Session**:
Authentication owned by an external agent provider or its official client, which Codex Usage Monitor may use but does not own or delete.
_Avoid_: App login, stored credential, connected agent

**Paired Agent**:
A Supported Agent that the user has explicitly connected to this app at least once and that remains known across active, inactive, connected, and disconnected states. Detecting an existing Provider Session never pairs an agent by itself; pairing history is retained indefinitely in the current product model.
_Avoid_: Connected agent, active agent, planned agent

**Active Agent**:
A Supported Agent whose monitoring is enabled in this app.
_Avoid_: Selected agent, enabled provider

**Connected Agent**:
A Supported Agent that this app is linked to through an authenticated, usable Provider Session.
_Avoid_: Active agent, provider session, globally signed-in account

**Disconnected Agent**:
A Supported Agent whose link to this app has been removed. Its Provider Session may still exist outside the app.
_Avoid_: Logged-out provider, deleted account, inactive agent

**Disconnect**:
The immediate app-local action that removes an agent's link, monitoring, and notifications without confirmation and without logging out or deleting its Provider Session.
_Avoid_: Logout, sign out, revoke credentials

**Agent Status Block**:
One read-only Context Rail summary for a Paired Agent, showing its identity and current active/connection state. Blocks remain alphabetical while they fit; when they overflow vertically, the Settings Agent is promoted to the top and the rest remain alphabetical. Agent switching belongs to the Agent Selector, not the block.
_Avoid_: Agent card, connected-only block, provider preview

**Settings Agent**:
The agent whose connection, privacy, quota, and Window Warning Settings are currently shown for editing. It is remembered only for the current Settings Window, defaults to the first Supported Agent alphabetically on each new window, and does not change menu-bar content.
_Avoid_: Selected agent, current agent, notification agent

**Agent Selector**:
The horizontally scrollable row in the Agents Settings Page Header that chooses the Settings Agent from every Supported Agent, including agents that have never been paired. Icon-leading items are ordered alphabetically, separated visually, and identify the current Settings Agent with an underline; a menu-style picker is only a narrow-layout or accessibility fallback.
_Avoid_: Provider tab, paired-agent filter, primary pop-up picker, Menu Bar Agent Selector

**Preferred Menu Bar Agent**:
The Connected Agent chosen by the user for Single-Agent Menu Bar Mode. The preference is independent from the Settings Agent and is not overwritten by temporary automatic failover.
_Avoid_: Selected agent, current agent, settings agent

**Effective Menu Bar Agent**:
The agent currently rendered in Single-Agent Menu Bar Mode. It normally equals the Preferred Menu Bar Agent but may temporarily be another Connected Agent under Switch Automatically.
_Avoid_: Preferred agent, selected agent, fallback preference

**Single-Agent Menu Bar Mode**:
The menu-bar presentation that renders one Effective Menu Bar Agent and may apply the Menu Bar Failover Policy.
_Avoid_: Default icon mode, selected-agent view

**Multi-Agent Menu Bar Mode**:
A planned menu-bar presentation that renders progress for multiple agents. Single-agent selection and failover rules do not govern this mode; their controls are provisionally disabled while their stored values are preserved.
_Avoid_: Dual quota view, automatic failover view

**Onboarding Acknowledgement**:
The app-local record that the current first-run tour was completed, skipped, or closed. It never pairs or activates an agent.
_Avoid_: Setup complete, connected, paired

## Local Token Activity

**Token Monitor**:
The menu-popover card showing token usage observed from an agent's local records on this Mac, distinct from provider-reported quota, billing, and account-wide usage. This name supersedes both **Dashboard** and **Token Activity** in everything a user reads; internal Swift type names still say `TokenActivity` and are deliberately not renamed.
_Avoid_: Dashboard, Token Activity, local quota, account usage, billing usage

**Token Monitor Visibility**:
The per-agent preference deciding whether that agent contributes a Token Monitor card. Turning it off also stops reading that agent's local records and discards its cached observations, so it is a collection decision rather than a display filter.
_Avoid_: Hide card, disable activity, pause monitoring

**Token Monitor Section**:
One toggleable region of the Token Monitor card — Activity chart, Token categories, Model usage, or Last request. Section toggles change only what is rendered; every section is derived from the same reconciled request set. The card's title, range line, range total, and request count are not sections and always remain.
_Avoid_: Card row, widget, module

**Token Monitor Range**:
The per-agent preference deciding whether a card reports the current local day (**Today**) or the current local week (**This week**), shown as the line under the card's title. It defaults to **Today**. The range decides which observed requests are in scope and how wide one chart bar is — 30-minute intervals for a day, one bar per day for a week — and nothing else: both views are aggregated from the same reconciled request set, and switching rereads no file.
_Avoid_: Time filter, period, rolling week, last 7 days

**Activity Interval**:
A 30-minute local-calendar segment whose value is the Observed Tokens attributed to provider-recorded completion times in that interval, not the cumulative total since midnight.
_Avoid_: Chart point, rolling window, cumulative interval

**Activity Chart**:
The bar chart of Activity Intervals from local midnight through the current interval. Hover identifies one interval without changing the card's summary rows.
_Avoid_: Line graph, cumulative chart, quota chart

**Observed Tokens**:
A provider-native token total derived from reconciled local records. Codex and Claude components retain their provider meanings and are not a cross-provider comparison.
_Avoid_: Account tokens, quota tokens, comparable tokens

**Model Usage**:
Observed Token Activity grouped by Short Model Name and ordered by contribution. The popover names the top three groups and combines the remainder as Other.
_Avoid_: Top model, model quota, model allowance

**Short Model Name**:
A compact model family and number such as GPT-5.6 or Sonnet 4.5; provider prefixes, product suffixes, and dated build identifiers are omitted.
_Avoid_: Raw model identifier, model alias, display label

**Last Request**:
The most recent reconciled local agent interaction for which token usage is observable.
_Avoid_: Latest request, latest response, last prompt

**Other**:
The combined Observed Tokens from models outside the three largest Model Usage groups for the current local day.
_Avoid_: Unknown model, hidden models, remaining usage

**Unknown Model**:
The Model Usage group for reconciled local requests that contain token evidence but no usable model identifier.
_Avoid_: Other, omitted model, invalid request

**No Activity**:
A readable local source with no Observed Tokens in the current local calendar day.
_Avoid_: Activity unavailable, zero quota, disconnected

**Activity Unavailable**:
The state in which local Token Activity cannot be read or reconciled safely; it does not mean that no activity occurred.
_Avoid_: No Activity, zero tokens, disconnected

**Local Records Missing**:
The state in which the provider's known local activity roots contain no readable session records yet.
_Avoid_: Activity Unavailable, No Activity, provider disconnected

**Paused Menu Bar State**:
The menu-bar presentation for an inactive Effective Menu Bar Agent, identified by a pause symbol before its usage statistics.
_Avoid_: Disconnected state, unavailable state, hidden agent

**Agent Settings Page**:
The Settings Agent's content within the Agents Settings Destination, including its connection, privacy, quota status, and provider-specific Window Warning Settings.
_Avoid_: Agent tab, provider page, agent destination

**Quota Window**:
A provider-defined usage allowance period, such as Codex's five-hour or weekly window.
_Avoid_: Lane, timeframe, quota tab

**Window Warning Settings**:
The threshold, forecasted-exhaustion, and reset/reset-failure preferences that apply independently to one Quota Window on an Agent Settings Page.
_Avoid_: Shared quota warnings, combined thresholds

**Global Warning**:
A warning configured once in the Notifications Settings Destination that applies across the app rather than one agent's Quota Window. Each agent's resulting stale-data, interruption, or reset-credit event retains its own provider identity and delivery state.
_Avoid_: Other warning, window warning

**Coalesced Interruption Notice**:
One notification that names every agent whose separate interruption episode became alert-eligible within the provisional five-second delivery-coalescing window. That window assumes agents refresh on a shared cadence and must be revisited if scheduling becomes provider-specific.
_Avoid_: Shared interruption episode, generic outage alert, duplicate provider notices
