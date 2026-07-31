# Claude usage — manual verification guide

This guide verifies the Claude paths that ship in Agent Monitor 0.0.1. It is a
real-machine smoke check, not a substitute for the automated suite.

> **Known 0.0.1 setup defect:** Claude setup has required unclear extra recovery
> in the published app. The exact failing boundary has not been reproduced, so
> record whether failure occurs during credential discovery, Keychain permission,
> passive status-line setup, or explicit CLI recovery instead of treating those
> paths as one generic “connection” failure.

## Current source hierarchy

| Tier | Source | Runtime status |
|---|---|---|
| 1 | OAuth usage endpoint using Claude Code's Keychain credential | Active |
| 2 | Claude CLI `/usage` | Manual-only; costs tokens |
| 3 | Passive `statusLine` snapshot written by the bundled native bridge | Active |
| 4 | App-owned last-known-good cache | Active |

Browser/setup-token sign-in is shelved as unverified and is not offered by the
shipped UI. The app may still read an existing app-owned credential or
`CLAUDE_CODE_OAUTH_TOKEN` as a compatibility fallback, but it does not create a
new setup-token credential through the release interface.

> **Keychain prompt boundary:** only an explicit user action may allow the
> cross-app Keychain prompt. Launch, scheduled refresh, wake refresh, and passive
> source discovery use a no-interaction query and must fail or degrade instead of
> raising a dialog.

## 1. Automated gate

From the repository root:

```sh
cd CodexUsageMonitor
swift test
```

Expected: the complete suite exits 0. The narrow Claude and release-regression
checks can also be rerun with:

```sh
swift test --filter Claude
swift test --filter LocalActivityReconciliationRegressionTests
swift test --filter LocalActivityMonitorRegressionTests
swift test --filter LocalDataActionsRegressionTests
```

## 2. Build the app bundle

The raw SwiftPM executable is insufficient for final Keychain, signing, resource,
or macOS UI verification.

```sh
cd CodexUsageMonitor
zsh Scripts/build-app.sh
Scripts/verify-signed-app-resources.sh
codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app
```

The published 0.0.1 artifact used the Developer ID identity and completed
notarization/stapling. Future release candidates must repeat those steps; ad-hoc
signing remains only a local development check and can cause Keychain approval to
reappear after rebuilds.

## 3. Explicit Claude Code credential connection

1. Open **Settings → Agents → Claude Code**.
2. Select **Use Claude Code credentials…** (or the equivalent first-run action).
3. Confirm macOS may present the `Claude Code-credentials` Keychain prompt.
4. Approve the read.
5. Confirm the page resolves to the regular connection/status surface and a
   confirmed OAuth reading appears when the credential and endpoint are usable.

The app must not ask for a password, print a token, or copy Claude Code's token
into app storage.

## 4. Background no-prompt boundary

After quitting the app, remove only the app's Keychain authorization through
Keychain Access if you need to reproduce a first-access state. Do not delete
Claude Code's credential.

1. Launch the signed app and do not press a Claude connection or manual-refresh
   control.
2. Leave it running through a scheduled refresh.
3. Wake the Mac or trigger the configured wake refresh.

Expected: no Keychain dialog appears. Claude may show passive, cached, unavailable,
or recovery state, but an automatic refresh must never interrupt the user.

## 5. Manual diagnostic probe

The headless probe is explicitly user-initiated and may show the Keychain prompt:

```sh
cd CodexUsageMonitor
.build/debug/CodexUsageMonitor --claude-live-read-once
```

Expected report properties:

- `tier1Method` is `claudeCodeCredentials` when Claude Code's item served;
- tier 2 says it is manual-only, not unimplemented;
- tier 3 reports a passive snapshot when `claude-rate-limits.json` exists;
- tier 4 reports the cached last-known-good when present;
- no access token, refresh token, email, prompt, response, path, or raw provider
  payload is printed.

## 6. Manual CLI `/usage` check

The Settings action that invokes `claude -p /usage` is intentionally manual
because it consumes tokens. Confirm the consent copy is visible before invoking
it, then compare its five-hour and weekly percentages with the app. Do not put
this command on a timer or treat it as part of the automatic collector.

## 7. Native passive bridge

The signed app bundles `claude-usage-bridge`, copies it to:

```text
~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/claude-usage-bridge
```

and can merge a `statusLine` command into `~/.claude/settings.json` without
overwriting an unrelated custom status line.

Inspect only the configured command and the normalized snapshot:

```sh
plutil -p ~/.claude/settings.json
plutil -p ~/Library/Application\ Support/CodexUsageMonitor/claude-rate-limits.json
```

Expected:

- the command points at the copied native executable, not Python or the source
  checkout;
- the snapshot contains schema/capture metadata and normalized rate-limit
  windows only;
- its freshness advances only when Claude Code renders a status line.

## 8. Cache and file permissions

```sh
ls -ld ~/Library/Application\ Support/CodexUsageMonitor
ls -l ~/Library/Application\ Support/CodexUsageMonitor/*.json
plutil -p ~/Library/Application\ Support/CodexUsageMonitor/claude-usage-cache.json
```

Expected:

- directory mode `0700`;
- app-owned JSON files mode `0600`;
- the Claude cache contains normalized usage metadata, delivery source, and
  capture time, never a credential.

## 9. Token Monitor privacy and correctness

Claude Token Monitor reads complete bounded JSONL lines into memory, selectively
decodes only message/request identity, timestamp, model, sidechain role, and the
four usage categories, then discards the raw bytes. It does not decode, retain,
export, or transmit conversation content.

Acceptance:

1. Confirm streaming chunks for one `(message ID, request ID)` produce one
   request.
2. Confirm distinct request IDs are not collapsed merely because a message ID is
   reused.
3. Confirm a nested `agent_progress` assistant record contributes usage.
4. Turn **Show token monitor** off for Claude and confirm its card disappears,
   file-event reads stop, its cache entry is removed, and re-enabling performs a
   fresh scan rather than reusing decoded source state.

## 10. Data & Privacy export

Use **Settings → Data & Privacy → Export Local Data…** and inspect the JSON at the
chosen destination.

Expected:

- every `LocalDataInventory` filename appears with an exported, missing, unsafe,
  or unreadable status;
- the export includes no Claude Keychain item and no provider-owned transcript;
- a symbolic link planted at an inventory filename is rejected rather than
  followed outside the app-owned directory.

## 11. Signed-app UI acceptance

At the default Settings size, check the Claude setup, connected, cached, passive,
unavailable, and recovery states in Light and Dark appearance with the Context
Rail hidden and visible. Also exercise provider switching, pointer activation,
keyboard traversal, VoiceOver labels, the manual CLI consent, and the Token
Monitor day/week states.

The popover's tallest Token Monitor state remains an explicitly accepted known
limitation for 0.0.1: it can exceed the usable height of a 1280×800 display. Do
not mark visual acceptance complete without either observing the documented
matrix or recording an explicit release waiver.

## Terms caveat

Anthropic's Terms of Service do not permit a third-party application to reuse
Claude Code's OAuth credential. The release deliberately ships with that caveat
disclosed in the README, release notes, and Data & Privacy page. Verification
that the mechanism works does not remove that policy risk.
