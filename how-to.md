The URLs you saw are the standard Codex-managed ChatGPT login flow. Port `1455` is Codex’s default localhost callback port.

Important: the callback URL you pasted contained a one-time authorization code. Treat it as sensitive. It is probably expired or already consumed, but don’t paste future callback URLs anywhere.

## The login flow

```text
codex login
    │
    ├─ creates a random state value
    ├─ creates a PKCE verifier/challenge
    ├─ starts http://localhost:1455
    └─ opens OpenAI consent
             │
             ▼
https://auth.openai.com/.../codex/consent
             │
             ▼
http://localhost:1455/auth/callback?code=...
             │
             ├─ Codex validates state
             ├─ Codex combines code + private PKCE verifier
             ├─ Codex exchanges them for tokens
             └─ Codex stores and refreshes the login
```

The callback URL is not something you manually execute. It only works while the original Codex process is listening and holding the matching PKCE verifier.

OpenAI documents Codex-managed ChatGPT authentication as the recommended mode: Codex owns the browser flow, tokens, storage, and refresh process. [Official Codex app-server authentication documentation](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md).

## Running it yourself

Open Terminal and check which Codex you have:

```bash
command -v codex
codex --version
```

Current detected installation:

```text
codex-cli 0.144.1
```

Start the browser login:

```bash
codex login
```

Keep that terminal open. Codex should:

1. Start the localhost callback server.
2. Open the OpenAI consent page.
3. Let you choose your ChatGPT account.
4. Redirect the browser to localhost.
5. Print a success result in Terminal.

Do not copy the callback URL. The browser should deliver it directly to the waiting Codex process.

### Device-code alternative

If localhost callbacks fail because of firewall, port conflicts, or remote-shell use:

```bash
codex login --device-auth
```

Codex will show a verification URL and short code. Open the URL, enter the code, and approve access. This avoids the localhost callback.

### Verify login

Check the current state with:

```bash
codex login status
```

The usage probe currently confirms the existing ChatGPT login successfully. If `codex login status` reports an authentication or configuration error in the future, do not manually edit or delete `~/.codex/auth.json`. First try:

```bash
codex login
```

A successful new login may rewrite it in the format expected by this CLI. If that fails, update the Codex CLI or the VS Code Codex extension before considering logout.

Be aware that this command removes the existing Codex login:

```bash
codex logout
```

Only use it intentionally, because other Codex surfaces sharing that login may require reconnection.

## Running our usage probe

After authentication, run:

```bash
cd "<USER_HOME>/Desktop/agent usage/UsageProbe"
python3 -m codex_probe
```

The default output is a compact, human-readable summary:

```text
Codex plan: plus
Credits: …
Available reset credits: …
  Reset credit expires: …
5-hour limit: …% used · …% remaining
  Resets: …
Weekly limit: …% used · …% remaining
  Resets: …
Verification: …
```

Use full JSON when troubleshooting or building on the probe:

```bash
python3 -m codex_probe --json
```

Meanings:

- `primary`: five-hour usage window.
- `secondary`: weekly usage window.
- `usedPercent`: consumed, not remaining.
- `remainingPercent`: unused portion of the window.
- `resetsAt`: Unix reset timestamp, included in `--json` output.
- `resetCreditExpiresAt`: expiry timestamps for earned reset credits, included only when Codex provides credit details.
- `300` minutes: five hours.
- `10080` minutes: seven days.

The probe does not send a model prompt or intentionally consume usage. It makes three separate read-only samples, rejects the known transient near-empty response pattern, and reports a result as unconfirmed if clean samples do not agree.

For confirmed results, it also verifies the hashed account identity and the main `codex` rate-limit lane. It saves the last confirmed non-secret snapshot locally at `~/.codex-usage-probe/last-known-good.json`; that file is used only when a later fresh read is unsafe or inconsistent. It contains no password, OAuth token, raw email address, prompt, or raw provider response.

## Running the native menu-bar app

Xcode 26.3 is installed in `/Applications/Xcode.app`. To make it the default developer toolchain, run this once in your own Terminal (macOS will ask for your administrator password):

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

The current MVP is a local Swift package that builds a menu-bar-only app bundle. It does not package or call the Codex `UsageProbe`. It does bundle the separate, zero-cost Claude status-line bridge described below.

```sh
cd "<USER_HOME>/Desktop/agent usage/CodexUsageMonitor"
bash Scripts/build-app.sh
open .build/CodexUsageMonitor.app
```

By default, the gauge icon appears in the menu bar with the most-consumed quota lane shown as its remaining percentage. In **Settings… > General > Menu Bar**, set **Appearance** to **5-hour and weekly** for a live label such as `5H: 64% | Week: 82%`. Set **Show** to **Used** to display the complementary used percentages instead; **Remaining** is the default. That presentation remains unchanged while Codex is the only provider with data. When Claude is the only usable read or both providers have data, the compact label selects whichever provider has the highest used percentage across its available windows and identifies it with the provider mark; **Show** changes the displayed value without changing which provider is selected. Missing reads are excluded rather than displayed as zero, and ties favor Codex before Claude. Cached/paused Codex values retain a pause marker when Codex is selected. When Codex is connected, open the menu to see the plan, credits, earned reset-credit expiries, five-hour and weekly usage/reset times, the confirmation state, and **Refresh now**. Quit it from the menu.

When the app cannot confirm a Codex account, the same menu shows a dedicated connection stage instead of quota controls:

- **Sign in with browser** asks `codex app-server` for the official provider URL, opens it in the default browser, and waits for Codex to confirm completion.
- **Sign in with Codex CLI…** opens Terminal and runs the located `codex login` command visibly. If the app was launched with a custom `CODEX_HOME`, the Terminal command preserves that same home. The app watches `codex login status` and confirms the result through `account/read`.
- **Settings…** and **Quit Codex Usage Monitor** remain at the bottom.

Both options require the Codex CLI. The first time you choose the CLI option, macOS may ask whether Codex Usage Monitor may control Terminal; this permission is used only to open the visible `codex login` session. If Codex is not found, install or update it and select **Check again** in Settings > Agents > OpenAI Codex. The monitor never asks for a password, reads `~/.codex/auth.json`, or stores tokens. A successful sign-in immediately triggers a fresh quota collection.

If Codex is signed out elsewhere while the monitor remains open, the next unavailable quota refresh rechecks `account/read` and moves the menu to the disconnected stage without requiring an app relaunch.

If you complete `codex login` independently while that disconnected stage is open, the monitor reads the same Codex home again when the app becomes active and at most every 30 seconds while it remains disconnected. This uses read-only `account/read`; it does not read credential files or start another quota schedule. Isolated acceptance observed both routes, but the exact refresh count and repeated-event coalescing remain manual checks.

The app performs the same three read-only `codex app-server` samples as the probe. It keeps a sanitized last-known-good result in `~/Library/Application Support/CodexUsageMonitor/last-known-good.json`, owner-readable only. That file contains a hashed account identity and normalized quota fields only—never a token, email address, prompt, or raw provider response.

Confirmed live results are also appended to `~/Library/Application Support/CodexUsageMonitor/quota-history.json`. The app retains at most 500 observations from the last 90 days, with the same owner-only permissions and privacy boundary. It calculates a forecast only from at least three confirmed readings spanning 15 minutes in the same reset window, with a consistently positive trend. The rate is the median of adjacent slopes. A valid row shows **Projected exhaustion** plus low, medium, or high confidence; projections at or after reset are hidden.

Every completed menu-bar refresh also appends a privacy-safe outcome to `~/Library/Application Support/CodexUsageMonitor/refresh-diagnostics.json`. It retains at most 1,000 entries from 30 days and stores timestamps, refresh reason, classified outcome, and an optional stable failure kind—never raw provider errors, account quota values, email, credentials, prompts, or RPC messages. Both the Application Support directory and files use owner-only permissions (`0700` and `0600`).

The monitor refreshes at launch, on **Refresh now**, and at the selected foreground interval while its process is running. The Refresh tab offers Automatic, 1 minute 30 seconds, 2 minutes (the default), 5 minutes, and 10 minutes; a saved legacy one-minute selection migrates to 1 minute 30 seconds. **Refresh on wake** defaults on and can be disabled. Opening the native menu never starts a refresh, timer, or second scheduler. Automatic considers confirmed usage rate, remaining quota, reset proximity, forecast confidence, and recent failures. Only Automatic may temporarily use 30 seconds near a warning threshold, qualified exhaustion, or reset verification; that burst ends after ten minutes, after its trigger passes, or after unsuccessful live reads. After three consecutive unsuccessful refreshes, every mode temporarily changes to a 10-minute retry cadence. A confirmed update automatically restores the selected healthy-state schedule. Only one collection runs at a time, and the manual button is disabled during an active refresh.

Open **Settings…** from the menu popover (or press `Command-,`) to use the separate Settings window. Its global `SettingsNavigationSidebar` selects General, Notifications, Refresh, Agents, Data & Privacy, and Diagnostics. It opens with the Context Rail hidden at 680 × 560 points. Use the page-header Context Rail button to show the 210-point rail; the window adds 211 points only at its right edge and the sidebar and Settings Page retain their width. Settings cards use consistent compact rows, dividers, native switches, and leading control descriptions. General groups **Launch at login** and **Enable keyboard shortcuts** together, then presents **Style**, **Show**, and Settings-window **Appearance** as bounded native segments. Appearance changes the Settings presentation only; the native menu remains controlled by macOS. Its one menu-bar preview is in the Context Rail; there is no page-level duplicate Preview, Current Label, or Current Scope. Diagnostics owns the app **Name**, **Version**, and **Build** rows. Launch at Login reflects the real macOS Login Items state and links to System Settings when approval is required. Disabling keyboard shortcuts removes the app-local `Command-R` binding while leaving both **Refresh now** buttons and the standard Settings/Quit commands available. Menu-bar controls update the menu label immediately. Quota values update after each launch, enabled wake trigger, authentication, manual, or scheduled refresh; fixed intervals are 90, 120, 300, or 600 seconds, while Automatic may temporarily use 30 or 60 seconds. Agents contains the supported OpenAI Codex and Claude Code pages. Claude's regular page shows connection, current quota, source, and the optional token-consuming CLI check. If this app has never connected to Claude or held a Claude reading, the Claude tab shows **Set up Claude usage** instead: **Connect with credentials** reads the OAuth token Claude Code stored in Keychain and macOS asks permission; passive capture can instead use Claude Code's configured status line. The app bundle includes the passive-capture bridge and copies it to `~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/` before use, but the one-click statusLine configuration/merge UI is still deferred. After any successful connection or reading, a later lapse keeps the regular status and recovery rows. Unsupported providers are omitted. Refresh contains the working interval selector, working wake switch, effective-policy explanation, timestamps, and **Refresh now**. Export and deletion remain later roadmap work.

A brief destination-switch text-compositing artifact is recorded as a deferred visual issue; it does not change settings values or monitoring behavior.

Preference pages keep the native macOS theme but use consistent page margins and aligned label/value rows. Longer pages scroll vertically; if the bottom of Notifications, Data & Privacy, or another tab is not visible, scroll inside the page rather than resizing the window. Helper text wraps instead of running beneath controls or past the window edge.

The notification master switch requests macOS notification permission only when enabled. Separate 50%, 25%, 10%, and 5% remaining toggles apply to both the five-hour and weekly lanes; qualified forecast and earned reset-credit-expiration warnings remain independently selectable. Turning the master switch off greys the subordinate warning controls without erasing their selections, while authorization status and **Open Notification Settings…** remain usable. Each lane and threshold is deduplicated within its current reset window. The app does not provide quiet hours; use macOS Focus or notification settings when notifications should be silenced on a schedule.

The local build script ad-hoc signs the completed bundle with the stable identifier `com.david.codex-usage-monitor` after installing its `Info.plist`. Always launch the `.app` produced by `Scripts/build-app.sh` when checking notification permission; running the raw SwiftPM executable does not provide the same macOS notification identity.

macOS normally shows the notification permission prompt only once. If permission was denied, toggling alerts cannot display the prompt again. The app will show the denied state and **Open Notification Settings…**; enable **Codex Usage Monitor** in System Settings, then return to the app and enable quota notifications. The popover and Settings controls share the same app preference and macOS authorization status.

The menu-bar content uses native menu presentation. **Refresh now**, **Settings…**, **Open Notification Settings…**, and **Quit Codex Usage Monitor** remain inline menu commands. Its stable refresh row shows the last attempt beside an absolute **Next refresh** time. It changes to **Refreshing…** when collection starts and to the newly scheduled absolute time when collection completes; it does not tick once per second while the native menu is tracking. **Confirmed / completed** means the latest attempt returned trusted live data. **Cached / paused** means it did not: the app retains and labels the last confirmed result when one exists, shows the last successful and attempted times, and never presents an unconfirmed result as current. When notifications are disabled, a concise standalone status row appears without overlapping refresh metadata or later commands.

Settings presents only privacy-safe status. It never displays the stored account fingerprint, email, credentials, prompts, raw provider responses, raw provider errors, or quota values inside Diagnostics. Data & Privacy lists the local Codex and Claude files, their owner-only permissions, and their applicable replacement or bounded-retention policies without export or deletion actions.

The current interface uses native SwiftUI. A separate future `feature/figma-ui-overhaul` branch will adapt approved Figma designs for app-owned Settings and Dashboard windows after their functional interfaces stabilize. It will not replace the menu's native inline commands or change data collection behavior without a separate decision.

The notification settings also control:

- confirmed quota-reset notifications;
- critical reset-failure warnings after two confirmed reads still show the prior window;
- stale-data warnings once the displayed snapshot is at least 15 minutes old and no interruption episode is active;
- one extended-interruption warning on the third consecutive read that fails to produce confirmed live data. It says the user may be disconnected without claiming a specific cause, persists its episode identity across relaunches, and does not repeat before recovery.

### Current hardening checkpoint

The quota-history foundation, reliability hardening, adaptive refresh, and Codex connection implementation compile successfully. The connection branch also passed a confirmed live one-shot collection, signed-bundle launch, and an isolated disconnected-process survival check. User-reported manual acceptance confirmed the disconnected menu and successful browser/CLI sign-in transitions; the app will not sign out the current account automatically for verification. Longer operational verification still includes leaving the menu-bar app running for more than five minutes, inspecting diagnostic field names and permissions, and completing the seven-calendar-day observation log before starting another provider or a UI overhaul.

For a terminal-only live diagnostic of the native collector (it performs one read and exits):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  .build/debug/CodexUsageMonitor --live-read-once
```

Run `bash Scripts/build-app.sh` first. The one-shot command is for troubleshooting and exercises the same repository, confirmation, cache, and history path as the app; use the `.app` for normal menu-bar use and notification permissions.

## How SessionWatcher likely fits

The URLs indicate that SessionWatcher is probably initiating or reusing the Codex-managed login flow. It is not necessarily collecting your OpenAI password itself.

The native application now uses this flow:

```text
Our app
   │
   ▼
launch codex app-server
   │
   ▼
account/login/start { type: "chatgpt" }
   │
   ▼
receive provider-created authUrl
   │
   ▼
open authUrl in default browser
   │
   ▼
wait for account/login/completed
```

This avoids implementing OAuth token exchange ourselves. Codex owns:

- PKCE generation;
- state validation;
- localhost callback;
- token exchange;
- credential storage;
- token refresh.

## One remaining issue

Login and quota accuracy are separate concerns.

A successful web login proves the account connection works. It does not guarantee every usage response is correct. Both CLI RPC and direct OAuth returned occasional inconsistent snapshots from the OpenAI usage backend.

The current reader already takes three read-only samples and compares reset times and percentage changes. A production collector still needs to:

- identify the account and `codex` limit;
- follow the complete app-server initialization sequence;
- confirm unexpected decreases with another read;
- compare reset timestamps;
- preserve the last-known-good snapshot.

In short: use `codex login` to reproduce the sign-in flow safely, then run `python3 -m codex_probe`. Never manually replay the localhost callback URL.
