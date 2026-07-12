# Codex capability probe

This Phase 0 harness checks whether the locally installed Codex exposes useful account limits and token-usage summaries without starting a model turn.

## Safety boundary

The process runner allows only:

- `codex --version`
- `codex login status`
- `codex doctor --json` (reserved for diagnostics)
- `codex app-server --listen stdio://`

The app-server session follows `initialize` → `initialized` → `account/read` → `account/rateLimits/read` → `account/usage/read`. It cannot execute prompts, log out, or consume reset credits. The probe never reads `auth.json`; it records metadata only for an explicit allowlist of non-secret local state files.

The app-server methods are experimental in the installed Codex schema, so successful results are classified as `experimental`, not `supported`.

## Run

From this directory:

```sh
python3 -m codex_probe
```

The default output is a compact summary of plan type, credits, earned reset credits and their expiry dates, five-hour usage, weekly usage, and reset times. The probe performs three read-only samples, rejects the observed transient near-empty response pattern, and labels a result unconfirmed when clean samples disagree.

For a confirmed result, the probe requires the same hashed account identity, the `codex` rate-limit lane, matching reset windows, and near-identical usage across clean samples. It saves only the last confirmed non-secret quota snapshot to `~/.codex-usage-probe/last-known-good.json`, with owner-only directory and file permissions. The stored snapshot contains a one-way account fingerprint, not the email address, credentials, prompts, or raw provider response.

Optional overrides:

```sh
python3 -m codex_probe --codex /path/to/codex --codex-home /path/to/.codex
python3 -m codex_probe --json
```

`--json` prints the complete normalized report. Raw app-server responses and credential contents are never included.

## Native app companion

The native Swift menu-bar MVP now lives in `../CodexUsageMonitor`. It independently implements this same read-only app-server protocol and validation policy; it does not embed or invoke this Python harness.

Build and launch it with:

```sh
cd ../CodexUsageMonitor
bash Scripts/build-app.sh
open .build/CodexUsageMonitor.app
```

This prototype is verified through compilation and live, read-only Codex responses at the user's direction. No generated test cases were added or run for this work.

The native app additionally retains a bounded sanitized history at `~/Library/Application Support/CodexUsageMonitor/quota-history.json`: maximum 500 confirmed observations and 90 days. It stores only provider/lane identifiers, a one-way account fingerprint, normalized quota windows, and collection times. The Python probe does not read or write that app history.
