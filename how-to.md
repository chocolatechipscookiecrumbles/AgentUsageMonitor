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

The current MVP is a local Swift package that builds a menu-bar-only app bundle. It does not package or call the Python probe.

```sh
cd "<USER_HOME>/Desktop/agent usage/CodexUsageMonitor"
bash Scripts/build-app.sh
open .build/CodexUsageMonitor.app
```

The gauge icon appears in the menu bar with the lowest remaining quota percentage. Open it to see the plan, credits, earned reset-credit expiries, five-hour and weekly usage/reset times, the confirmation state, and **Refresh now**. Quit it from the menu.

The app performs the same three read-only `codex app-server` samples as the probe. It keeps a sanitized last-known-good result in `~/Library/Application Support/CodexUsageMonitor/last-known-good.json`, owner-readable only. That file contains a hashed account identity and normalized quota fields only—never a token, email address, prompt, or raw provider response.

Confirmed live results are also appended to `~/Library/Application Support/CodexUsageMonitor/quota-history.json`. The app retains at most 500 observations from the last 90 days, with the same owner-only permissions and privacy boundary. It calculates a forecast only from at least three confirmed readings spanning 15 minutes in the same reset window, with a consistently positive trend. The rate is the median of adjacent slopes. A valid row shows **Projected exhaustion** plus low, medium, or high confidence; projections at or after reset are hidden.

Every completed menu-bar refresh also appends a privacy-safe outcome to `~/Library/Application Support/CodexUsageMonitor/refresh-diagnostics.json`. It retains at most 1,000 entries from 30 days and stores timestamps, refresh reason, classified outcome, and an optional stable failure kind—never raw provider errors, account quota values, email, credentials, prompts, or RPC messages. Both the Application Support directory and files use owner-only permissions (`0700` and `0600`).

The monitor refreshes at launch, every five minutes while its process is running, after wake, and on **Refresh now**. Only one collection runs at a time; the manual button is disabled during an active refresh. Forecast alerts require confirmed live data, medium or high confidence, and projected exhaustion at least 15 minutes before reset.

Open **Settings…** from the menu popover (or press `Command-,`) to configure notifications. The master switch requests macOS notification permission only when enabled. Separate switches control the existing fixed 50%, 25%, 10%, and 5% remaining-quota warnings, qualified forecast warnings, and earned reset-credit-expiration warnings. Each lane and threshold is deduplicated within its current reset window.

The local build script ad-hoc signs the completed bundle with the stable identifier `com.david.codex-usage-monitor` after installing its `Info.plist`. Always launch the `.app` produced by `Scripts/build-app.sh` when checking notification permission; running the raw SwiftPM executable does not provide the same macOS notification identity.

macOS normally shows the notification permission prompt only once. If permission was denied, toggling alerts cannot display the prompt again. The app will show the denied state and **Open Notification Settings…**; enable **Codex Usage Monitor** in System Settings, then return to the app and enable quota notifications. The popover and Settings controls share the same app preference and macOS authorization status.

The menu-bar content uses native menu presentation. **Refresh now**, **Settings…**, **Open Notification Settings…**, and **Quit Codex Usage Monitor** remain inline menu commands. When notifications are disabled, a concise standalone status row appears without overlapping **Last refresh** or later commands.

The notification settings also control:

- confirmed quota-reset notifications;
- critical reset-failure warnings after two confirmed reads still show the prior window;
- stale-data warnings once the displayed snapshot is at least 15 minutes old;
- repeated-refresh warnings after three consecutive reads fail to produce confirmed live data.

Optional quiet hours use local wall-clock time and may cross midnight. Noncritical notifications are held in memory and delivered after quiet hours when the app next evaluates quota. The **Allow critical warnings** option permits only 5%-remaining and verified reset-failure warnings during quiet hours. Quiet-hour changes are calculated with the current calendar and time zone, including daylight-saving transitions.

### Current hardening checkpoint

The quota-history foundation and the implementation portions of reliability hardening Tasks 1–4 compile successfully. The remaining verification is operational: leave the menu-bar app running for more than five minutes to confirm foreground-independent refresh, inspect the diagnostic file's field names and permissions, and complete the seven-calendar-day observation log before starting another provider or a UI overhaul.

For a terminal-only live diagnostic of the native collector (it performs one read and exits):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  .build/debug/CodexUsageMonitor --live-read-once
```

Run `bash Scripts/build-app.sh` first. The one-shot command is for troubleshooting and exercises the same repository, confirmation, cache, and history path as the app; use the `.app` for normal menu-bar use and notification permissions.

## How SessionWatcher likely fits

The URLs indicate that SessionWatcher is probably initiating or reusing the Codex-managed login flow. It is not necessarily collecting your OpenAI password itself.

For our eventual application, the safest implementation is:

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
