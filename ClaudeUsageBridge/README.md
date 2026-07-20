# Claude statusLine usage bridge

This is a Phase 0 harness that captures Claude Code's own official `rate_limits`
fields — the same 5-hour and weekly `used_percentage`/`resets_at` values Claude
Code already computes from real API response headers — into a small local
snapshot file, at zero additional token cost. See the
[capability research](../docs/superpowers/plans/2026-07-20-claude-code-capability-research.md)
this implements (Signal A).

## Safety boundary

This script reads exactly one JSON object from stdin — the payload Claude
Code's own `statusLine` feature already sends after a real turn — and persists
**only** these fields:

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

Claude Code supports one `statusLine` command. Add or merge this into
`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "cd '/absolute/path/to/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet"
  }
}
```

(`--quiet` is optional; drop it if you want this bridge's own compact "Claude usage: 5h N% · 7d N%" line to also show as your status line.)

If you already have a custom `statusLine` script, call this bridge from
within it instead of replacing your script — for example, pipe your existing
stdin payload to `python3 -m claude_usage_bridge --quiet` from
`ClaudeUsageBridge/` as an additional step, so your own status line keeps
rendering unchanged.

## Run manually

From this directory:

```sh
echo '{"rate_limits": {"five_hour": {"used_percentage": 12.0, "resets_at": 1800000000}}}' | python3 -m claude_usage_bridge
```

Optional overrides:

```sh
python3 -m claude_usage_bridge --output /path/to/snapshot.json
python3 -m claude_usage_bridge --quiet
```

## Native app companion

The snapshot this bridge writes is read by `ClaudeRateLimitSnapshotReader` in
the native app (`CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/`). As of
this plan, that reader is an isolated, tested component only — it is not yet
wired into any Settings UI, connection controller, or refresh cycle. See the
[capability research's gate](../docs/superpowers/plans/2026-07-20-claude-code-capability-research.md#gate-before-implementation)
for what still has to be true before a visible Claude usage UI ships.
