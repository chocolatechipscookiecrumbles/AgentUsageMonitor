# Claude status-line usage bridge

Agent Monitor’s main `CodexUsageMonitor` executable also provides a headless
Claude status-line mode. When invoked through the stable
`claude-usage-bridge` basename—or with `--claude-usage-bridge` for diagnostics—
it dispatches before SwiftUI or AppKit starts. There is no separate executable
product or nested signed helper.

`CodexUsageMonitor/Sources/CodexUsageMonitor/ClaudeUsageBridgeCommand.swift`
owns argument and process dispatch.
`CodexUsageMonitor/Sources/ClaudeUsageBridgeCore/` contains the pure,
dependency-free payload logic shared by the app.

## Safety boundary

The bridge reads one JSON object from stdin: the payload Claude Code sends to
its official `statusLine` command after a real turn. It persists only:

- `rate_limits.five_hour.used_percentage` and `resets_at`
- `rate_limits.seven_day.used_percentage` and `resets_at`

It does not retain working-directory, Git, context-window, model, prompt,
response, or other payload fields. It makes no network request, consumes no
tokens, reads no credential, and never starts or configures the Claude CLI.

The normalized snapshot is written atomically to:

```text
~/Library/Application Support/CodexUsageMonitor/claude-rate-limits.json
```

The directory is owner-only (`0700`) and the file is owner-only (`0600`).

## Setup and custom status lines

**Connect Claude** installs an app-owned stable symlink at:

```text
~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/claude-usage-bridge
```

The symlink targets the signed main executable inside the `.app`. Agent Monitor
adds that stable path to `~/.claude/settings.json` only when no foreign status
line would be replaced. A custom status line is preserved; integrate the bridge
into that script manually if both outputs are required.

The managed command uses `--quiet` so capture does not replace Claude Code’s
visible status text. Without `--quiet`, bridge mode also prints its compact
usage line.

## Build and diagnose manually

Build the main executable:

```sh
cd CodexUsageMonitor
swift build --product CodexUsageMonitor
```

Exercise bridge mode with sanitized input and an isolated output file:

```sh
tmp_output="$(mktemp)"
echo '{"rate_limits":{"five_hour":{"used_percentage":12.0,"resets_at":1800000000}}}' \
  | .build/debug/CodexUsageMonitor --claude-usage-bridge --quiet --output "$tmp_output"
plutil -p "$tmp_output"
```

The shipped app uses the basename symlink rather than the explicit diagnostic
flag. Both routes enter the same pre-UI command implementation.
