# Claude statusLine usage bridge

A tiny native helper that captures Claude Code's own official `rate_limits`
fields — the same 5-hour and weekly `used_percentage`/`resets_at` values Claude
Code already computes from real API response headers — into a small local
snapshot file, at zero additional token cost. See the
[capability research](../docs/superpowers/plans/2026-07-20-claude-code-capability-research.md)
this implements (Signal A).

> **Now native (Swift).** This bridge was originally a Python module. It has been
> rewritten as a dependency-free Swift executable so a shipped build does not
> require the user to have `python3` installed. The source lives in the app's
> Swift package:
> - executable: `CodexUsageMonitor/Sources/ClaudeUsageBridge/`
> - shared logic: `CodexUsageMonitor/Sources/ClaudeUsageBridgeCore/`
> - tests: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageBridgeTests.swift`

## Safety boundary

The bridge reads exactly one JSON object from stdin — the payload Claude Code's
own `statusLine` feature already sends after a real turn — and persists **only**
these fields:

- `rate_limits.five_hour.used_percentage`, `rate_limits.five_hour.resets_at`
- `rate_limits.seven_day.used_percentage`, `rate_limits.seven_day.resets_at`

It never reads, logs, or persists `cwd`, `git`, `context_window`, `model`, or
any other field from that payload. It never calls any network endpoint, never
reads `~/.claude/.credentials.json` or any other Claude Code credential file,
and never starts, configures, or invokes the `claude` CLI itself — it only
processes what Claude Code chooses to send it as a configured `statusLine`
command. It writes the extracted snapshot atomically to
`~/Library/Application Support/CodexUsageMonitor/claude-rate-limits.json`
with owner-only directory (`0700`) and file (`0600`) permissions.

## Setup

Claude Code supports one `statusLine` command. The app installs it for you by
merging this into `~/.claude/settings.json` (pointing at the copy it places in
Application Support):

```json
{
  "statusLine": {
    "type": "command",
    "command": "'/absolute/path/to/claude-usage-bridge' --quiet"
  }
}
```

(`--quiet` is optional; drop it if you want this bridge's own compact
"Claude usage: 5h N% · 7d N%" line to also show as your status line.)

If you already have a custom `statusLine` script, call this bridge from within
it instead of replacing your script — pipe your existing stdin payload to the
`claude-usage-bridge` executable as an additional step, so your own status line
keeps rendering unchanged.

## Build and run manually

```sh
cd CodexUsageMonitor
swift build --product claude-usage-bridge
echo '{"rate_limits": {"five_hour": {"used_percentage": 12.0, "resets_at": 1800000000}}}' \
  | .build/debug/claude-usage-bridge
```

Optional overrides:

```sh
.build/debug/claude-usage-bridge --output /path/to/snapshot.json
.build/debug/claude-usage-bridge --quiet
```

## Native app companion

The snapshot this bridge writes is read by `ClaudeRateLimitSnapshotReader` in
the native app (`CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/`). The app
bundles the `claude-usage-bridge` executable as a signed resource, copies it to
`~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/` (stripping the
download quarantine so Claude Code can exec it), and uses it as the passive
fallback behind the supported Claude Settings page. Interactive one-click
installation and conflict merging for an existing custom `statusLine` remain
deferred; manual setup must preserve an existing command.
