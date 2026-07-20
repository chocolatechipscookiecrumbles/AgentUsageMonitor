# Claude StatusLine Usage Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-cost, privacy-scoped bridge that captures Claude Code's own official `rate_limits` (5-hour/weekly `used_percentage` + `resets_at`) from its `statusLine` payload into a small local snapshot file, plus an isolated, tested Swift reader for that file — with no wiring into any visible UI, connection controller, or refresh cycle.

**Architecture:** A standalone Python script (`ClaudeUsageBridge`), configured as the user's Claude Code `statusLine` command, receives Claude Code's own stdin JSON on every real status-line render and extracts only the `rate_limits` fields, writing them atomically to `~/Library/Application Support/CodexUsageMonitor/claude-rate-limits.json` with owner-only permissions. A separate, read-only Swift component (`ClaudeRateLimitSnapshotReader`) decodes that file. Nothing in this plan calls Anthropic's servers, reads Claude Code's credentials, or touches conversation content — this is exactly Signal A from the [Claude Code capability research](2026-07-20-claude-code-capability-research.md#authoritative-signal-probe-statusline-vs-oauth-endpoint--2026-07-20).

**Tech Stack:** Python 3 (stdlib only, no dependencies, matching `UsageProbe`'s existing zero-dependency approach) for the bridge; Swift 6.2 / Foundation for the reader; `pytest` for the bridge's tests; `XCTest` for the reader's tests.

## Global Constraints

- Extract and persist **only** `rate_limits.five_hour` / `rate_limits.seven_day` `used_percentage` and `resets_at`. Never read, log, or persist any other field from the statusLine payload (`cwd`, `git`, `context_window`, `model`, or anything else) — per the capability research's privacy boundary.
- Output file permissions: directory `0700`, file `0600`, written atomically (temp file + `os.replace`/rename) — mirrors `UsageProbe`'s "owner-only directory and file permissions" and `QuotaHistoryStore.swift`'s existing `0700`/`0600` pattern.
- Python: standard library only, no new dependencies, matching `UsageProbe/codex_probe`'s existing style (`from __future__ import annotations`, frozen dataclasses, `argparse`).
- Swift: macOS 14 platform floor per `CodexUsageMonitor/Package.swift`; follow `QuotaHistoryStore.swift`'s existing file-store conventions (Application Support directory, atomic write pattern) for the reader side.
- Do **not** modify `ClaudeCodePreviewSettingsView.swift`, `AgentSettingsCatalog.swift`, `AgentProvider.swift`, `SettingsView.swift`, or add any polling/refresh/notification/ViewModel wiring. Per the capability research's gate, only criteria 1–2 (a documented zero-cost source) are satisfied; criteria 3–5 (product-copy accuracy, single read-cycle owner, explicit "not available" fallback) remain open and are out of scope for this plan.
- Keep automated tests narrow and deterministic, per `AGENTS.md`; no broad test suites beyond what each task's deliverable needs.
- Do not modify `UsageProbe/`; this is a new, separate component with its own safety-boundary documentation.

---

## File Structure

- Create: `ClaudeUsageBridge/claude_usage_bridge/__init__.py`
- Create: `ClaudeUsageBridge/claude_usage_bridge/models.py` — `RateLimitWindow`, `RateLimitSnapshot`, `extract_snapshot()`
- Create: `ClaudeUsageBridge/claude_usage_bridge/writer.py` — `default_output_path()`, `write_snapshot()`
- Create: `ClaudeUsageBridge/claude_usage_bridge/cli.py` — `parse_args()`, `main()`
- Create: `ClaudeUsageBridge/claude_usage_bridge/__main__.py`
- Create: `ClaudeUsageBridge/tests/__init__.py`
- Create: `ClaudeUsageBridge/tests/test_models.py`
- Create: `ClaudeUsageBridge/tests/test_writer.py`
- Create: `ClaudeUsageBridge/tests/test_cli.py`
- Create: `ClaudeUsageBridge/README.md` — safety boundary + manual `statusLine` setup instructions
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshot.swift` — `ClaudeRateLimitWindow`, `ClaudeRateLimitSnapshot`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift` — `ClaudeRateLimitSnapshotReader`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotTests.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotReaderTests.swift`
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md` — record that the reader now exists as evidence toward gate criteria 1–2
- Modify: `docs/product/planning-board.md` — bookkeeping only

---

## Task 1: Bridge field extraction (`models.py`)

**Files:**
- Create: `ClaudeUsageBridge/claude_usage_bridge/__init__.py`
- Create: `ClaudeUsageBridge/claude_usage_bridge/models.py`
- Test: `ClaudeUsageBridge/tests/test_models.py`

**Interfaces:**
- Produces: `RateLimitWindow(used_percentage: float, resets_at: int)`, `RateLimitSnapshot(captured_at: int, five_hour: RateLimitWindow | None, seven_day: RateLimitWindow | None)` with `.to_dict()` on both; `extract_snapshot(payload: dict, captured_at: int) -> RateLimitSnapshot | None`.

- [ ] **Step 1: Create empty package files**

```bash
mkdir -p "ClaudeUsageBridge/claude_usage_bridge" "ClaudeUsageBridge/tests"
touch "ClaudeUsageBridge/claude_usage_bridge/__init__.py" "ClaudeUsageBridge/tests/__init__.py"
```

- [ ] **Step 2: Write the failing tests**

Create `ClaudeUsageBridge/tests/test_models.py`:

```python
from __future__ import annotations

from claude_usage_bridge.models import RateLimitSnapshot, RateLimitWindow, extract_snapshot


def test_extract_snapshot_with_both_windows():
    payload = {
        "rate_limits": {
            "five_hour": {"used_percentage": 23.5, "resets_at": 1_800_000_000},
            "seven_day": {"used_percentage": 41.2, "resets_at": 1_800_500_000},
        }
    }

    snapshot = extract_snapshot(payload, captured_at=1_700_000_000)

    assert snapshot == RateLimitSnapshot(
        captured_at=1_700_000_000,
        five_hour=RateLimitWindow(used_percentage=23.5, resets_at=1_800_000_000),
        seven_day=RateLimitWindow(used_percentage=41.2, resets_at=1_800_500_000),
    )


def test_extract_snapshot_with_one_window_absent():
    payload = {"rate_limits": {"five_hour": {"used_percentage": 10.0, "resets_at": 1_800_000_000}}}

    snapshot = extract_snapshot(payload, captured_at=1_700_000_000)

    assert snapshot is not None
    assert snapshot.five_hour is not None
    assert snapshot.seven_day is None


def test_extract_snapshot_returns_none_when_rate_limits_missing():
    assert extract_snapshot({"context_window": {}}, captured_at=1_700_000_000) is None


def test_extract_snapshot_returns_none_when_both_windows_absent():
    assert extract_snapshot({"rate_limits": {}}, captured_at=1_700_000_000) is None


def test_extract_snapshot_returns_none_for_malformed_window():
    payload = {"rate_limits": {"five_hour": {"used_percentage": "not-a-number", "resets_at": 1_800_000_000}}}

    assert extract_snapshot(payload, captured_at=1_700_000_000) is None


def test_extract_snapshot_ignores_every_non_rate_limit_field():
    payload = {
        "rate_limits": {"five_hour": {"used_percentage": 5.0, "resets_at": 1_800_000_000}},
        "cwd": "<USER_HOME>/secret-project",
        "context_window": {"used_percentage": 12},
        "model": {"display_name": "Sonnet"},
    }

    snapshot = extract_snapshot(payload, captured_at=1_700_000_000)

    assert snapshot.to_dict() == {
        "schemaVersion": 1,
        "capturedAt": 1_700_000_000,
        "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1_800_000_000},
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_models.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'claude_usage_bridge.models'`

- [ ] **Step 3: Write the implementation**

Create `ClaudeUsageBridge/claude_usage_bridge/models.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class RateLimitWindow:
    used_percentage: float
    resets_at: int

    def to_dict(self) -> dict[str, float | int]:
        return {"usedPercentage": self.used_percentage, "resetsAt": self.resets_at}


@dataclass(frozen=True)
class RateLimitSnapshot:
    captured_at: int
    five_hour: RateLimitWindow | None
    seven_day: RateLimitWindow | None

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"schemaVersion": 1, "capturedAt": self.captured_at}
        if self.five_hour is not None:
            result["fiveHour"] = self.five_hour.to_dict()
        if self.seven_day is not None:
            result["sevenDay"] = self.seven_day.to_dict()
        return result


def extract_snapshot(payload: object, captured_at: int) -> RateLimitSnapshot | None:
    """Extract only the rate_limits fields from a Claude Code statusLine payload.

    Returns None when rate_limits is absent, malformed, or has neither window,
    so callers can leave a previously written snapshot untouched instead of
    overwriting it with an empty one.
    """
    if not isinstance(payload, dict):
        return None
    rate_limits = payload.get("rate_limits")
    if not isinstance(rate_limits, dict):
        return None
    five_hour = _window_from_dict(rate_limits.get("five_hour"))
    seven_day = _window_from_dict(rate_limits.get("seven_day"))
    if five_hour is None and seven_day is None:
        return None
    return RateLimitSnapshot(captured_at=captured_at, five_hour=five_hour, seven_day=seven_day)


def _window_from_dict(value: object) -> RateLimitWindow | None:
    if not isinstance(value, dict):
        return None
    used_percentage = value.get("used_percentage")
    resets_at = value.get("resets_at")
    if not isinstance(used_percentage, (int, float)) or isinstance(used_percentage, bool):
        return None
    if not isinstance(resets_at, int) or isinstance(resets_at, bool):
        return None
    return RateLimitWindow(used_percentage=float(used_percentage), resets_at=resets_at)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_models.py -v`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageBridge/claude_usage_bridge/__init__.py ClaudeUsageBridge/claude_usage_bridge/models.py \
  ClaudeUsageBridge/tests/__init__.py ClaudeUsageBridge/tests/test_models.py
git commit -m "Add field-scoped rate_limits extraction for the Claude statusLine bridge"
```

---

## Task 2: Atomic, owner-only snapshot writer (`writer.py`)

**Files:**
- Create: `ClaudeUsageBridge/claude_usage_bridge/writer.py`
- Test: `ClaudeUsageBridge/tests/test_writer.py`

**Interfaces:**
- Consumes: `RateLimitSnapshot` from Task 1 (`.to_dict()`).
- Produces: `default_output_path() -> Path`, `write_snapshot(snapshot: RateLimitSnapshot, output_path: Path) -> None`.

- [ ] **Step 1: Write the failing tests**

Create `ClaudeUsageBridge/tests/test_writer.py`:

```python
from __future__ import annotations

import json
import stat

from claude_usage_bridge.models import RateLimitSnapshot, RateLimitWindow
from claude_usage_bridge.writer import write_snapshot


def test_write_snapshot_creates_owner_only_file(tmp_path):
    output_path = tmp_path / "support" / "claude-rate-limits.json"
    snapshot = RateLimitSnapshot(
        captured_at=1_700_000_000,
        five_hour=RateLimitWindow(used_percentage=10.0, resets_at=1_800_000_000),
        seven_day=None,
    )

    write_snapshot(snapshot, output_path)

    assert output_path.exists()
    assert json.loads(output_path.read_text()) == snapshot.to_dict()
    assert stat.S_IMODE(output_path.stat().st_mode) == stat.S_IRUSR | stat.S_IWUSR
    assert stat.S_IMODE(output_path.parent.stat().st_mode) == stat.S_IRWXU


def test_write_snapshot_overwrites_previous_snapshot(tmp_path):
    output_path = tmp_path / "claude-rate-limits.json"
    first = RateLimitSnapshot(captured_at=1, five_hour=RateLimitWindow(used_percentage=1.0, resets_at=2), seven_day=None)
    second = RateLimitSnapshot(captured_at=3, five_hour=RateLimitWindow(used_percentage=4.0, resets_at=5), seven_day=None)

    write_snapshot(first, output_path)
    write_snapshot(second, output_path)

    assert json.loads(output_path.read_text()) == second.to_dict()


def test_write_snapshot_leaves_no_temp_file_behind(tmp_path):
    output_path = tmp_path / "claude-rate-limits.json"
    snapshot = RateLimitSnapshot(captured_at=1, five_hour=None, seven_day=RateLimitWindow(used_percentage=2.0, resets_at=3))

    write_snapshot(snapshot, output_path)

    remaining = list(tmp_path.iterdir())
    assert remaining == [output_path]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_writer.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'claude_usage_bridge.writer'`

- [ ] **Step 3: Write the implementation**

Create `ClaudeUsageBridge/claude_usage_bridge/writer.py`:

```python
from __future__ import annotations

import json
import os
import stat
import tempfile
from pathlib import Path

from .models import RateLimitSnapshot


def default_output_path() -> Path:
    return Path.home() / "Library" / "Application Support" / "CodexUsageMonitor" / "claude-rate-limits.json"


def write_snapshot(snapshot: RateLimitSnapshot, output_path: Path) -> None:
    """Atomically write the snapshot with owner-only directory/file permissions."""
    directory = output_path.parent
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, stat.S_IRWXU)
    fd, temp_name = tempfile.mkstemp(dir=directory, prefix=".claude-rate-limits-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(snapshot.to_dict(), handle, sort_keys=True)
        os.chmod(temp_name, stat.S_IRUSR | stat.S_IWUSR)
        os.replace(temp_name, output_path)
    except BaseException:
        os.unlink(temp_name)
        raise
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_writer.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsageBridge/claude_usage_bridge/writer.py ClaudeUsageBridge/tests/test_writer.py
git commit -m "Add atomic, owner-only writer for the Claude statusLine bridge snapshot"
```

---

## Task 3: CLI entry point (`cli.py`, `__main__.py`)

**Files:**
- Create: `ClaudeUsageBridge/claude_usage_bridge/cli.py`
- Create: `ClaudeUsageBridge/claude_usage_bridge/__main__.py`
- Test: `ClaudeUsageBridge/tests/test_cli.py`

**Interfaces:**
- Consumes: `extract_snapshot` (Task 1), `default_output_path`/`write_snapshot` (Task 2).
- Produces: `parse_args(arguments: Sequence[str] | None) -> argparse.Namespace`, `main(arguments: Sequence[str] | None = None) -> int`.

- [ ] **Step 1: Write the failing tests**

Create `ClaudeUsageBridge/tests/test_cli.py`:

```python
from __future__ import annotations

import io
import json

from claude_usage_bridge.cli import main


def test_main_writes_snapshot_and_prints_status(tmp_path, monkeypatch, capsys):
    output_path = tmp_path / "claude-rate-limits.json"
    payload = json.dumps({"rate_limits": {"five_hour": {"used_percentage": 12.0, "resets_at": 1_800_000_000}}})
    monkeypatch.setattr("sys.stdin", io.StringIO(payload))

    exit_code = main(["--output", str(output_path)])

    assert exit_code == 0
    assert output_path.exists()
    assert "5h 12%" in capsys.readouterr().out


def test_main_quiet_suppresses_output(tmp_path, monkeypatch, capsys):
    output_path = tmp_path / "claude-rate-limits.json"
    payload = json.dumps({"rate_limits": {"five_hour": {"used_percentage": 12.0, "resets_at": 1_800_000_000}}})
    monkeypatch.setattr("sys.stdin", io.StringIO(payload))

    main(["--output", str(output_path), "--quiet"])

    assert capsys.readouterr().out == ""
    assert output_path.exists()


def test_main_leaves_existing_snapshot_when_rate_limits_absent(tmp_path, monkeypatch):
    output_path = tmp_path / "claude-rate-limits.json"
    output_path.write_text(json.dumps({
        "schemaVersion": 1,
        "capturedAt": 1,
        "fiveHour": {"usedPercentage": 9.0, "resetsAt": 2},
    }))
    monkeypatch.setattr("sys.stdin", io.StringIO(json.dumps({"context_window": {}})))

    main(["--output", str(output_path), "--quiet"])

    assert json.loads(output_path.read_text())["fiveHour"]["usedPercentage"] == 9.0


def test_main_handles_malformed_stdin_without_crashing(tmp_path, monkeypatch, capsys):
    output_path = tmp_path / "claude-rate-limits.json"
    monkeypatch.setattr("sys.stdin", io.StringIO("not json"))

    exit_code = main(["--output", str(output_path)])

    assert exit_code == 0
    assert not output_path.exists()
    assert "unavailable" in capsys.readouterr().out
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_cli.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'claude_usage_bridge.cli'`

- [ ] **Step 3: Write the implementation**

Create `ClaudeUsageBridge/claude_usage_bridge/cli.py`:

```python
from __future__ import annotations

import argparse
import json
import sys
import time
from collections.abc import Sequence
from pathlib import Path

from .models import RateLimitSnapshot, extract_snapshot
from .writer import default_output_path, write_snapshot


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="claude-usage-bridge",
        description="Extract only rate_limits fields from a Claude Code statusLine payload and write them locally.",
    )
    parser.add_argument("--output", type=Path, default=None, help="Override the snapshot output path")
    parser.add_argument("--quiet", action="store_true", help="Write the snapshot without printing a status line")
    return parser.parse_args(arguments)


def main(arguments: Sequence[str] | None = None) -> int:
    options = parse_args(arguments)
    output_path = options.output or default_output_path()

    try:
        payload = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        payload = None

    snapshot = extract_snapshot(payload, captured_at=int(time.time()))
    if snapshot is not None:
        write_snapshot(snapshot, output_path)

    if not options.quiet:
        print(_status_line(snapshot))
    return 0


def _status_line(snapshot: RateLimitSnapshot | None) -> str:
    if snapshot is None:
        return "Claude usage: unavailable"
    parts = []
    if snapshot.five_hour is not None:
        parts.append(f"5h {snapshot.five_hour.used_percentage:.0f}%")
    if snapshot.seven_day is not None:
        parts.append(f"7d {snapshot.seven_day.used_percentage:.0f}%")
    return "Claude usage: " + " · ".join(parts) if parts else "Claude usage: unavailable"
```

Create `ClaudeUsageBridge/claude_usage_bridge/__main__.py`:

```python
from .cli import main

raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/test_cli.py -v`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the full bridge test suite**

Run: `cd ClaudeUsageBridge && python3 -m pytest tests/ -v`
Expected: PASS (13 tests total across Tasks 1–3)

- [ ] **Step 6: Commit**

```bash
git add ClaudeUsageBridge/claude_usage_bridge/cli.py ClaudeUsageBridge/claude_usage_bridge/__main__.py \
  ClaudeUsageBridge/tests/test_cli.py
git commit -m "Add CLI entry point for the Claude statusLine bridge"
```

---

## Task 4: Bridge README (safety boundary + manual setup)

**Files:**
- Create: `ClaudeUsageBridge/README.md`

**Interfaces:** None (documentation only).

- [ ] **Step 1: Write the README**

Create `ClaudeUsageBridge/README.md`:

```markdown
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
    "command": "python3 /absolute/path/to/ClaudeUsageBridge/claude_usage_bridge -m"
  }
}
```

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
```

- [ ] **Step 2: Commit**

```bash
git add ClaudeUsageBridge/README.md
git commit -m "Document the Claude statusLine bridge safety boundary and setup"
```

---

## Task 5: Swift snapshot model

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshot.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotTests.swift`

**Interfaces:**
- Produces: `ClaudeRateLimitWindow(usedPercentage: Double, resetsAt: Date)`, `ClaudeRateLimitSnapshot(schemaVersion: Int, capturedAt: Date, fiveHour: ClaudeRateLimitWindow?, sevenDay: ClaudeRateLimitWindow?)`, both `Codable, Equatable`. JSON keys match the bridge's `to_dict()` output exactly (`schemaVersion`, `capturedAt`, `fiveHour`, `sevenDay`, `usedPercentage`, `resetsAt`), with epoch-seconds encoding for the two date fields (not ISO 8601, since the bridge writes plain Unix timestamps).

- [ ] **Step 1: Write the failing test**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeRateLimitSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let snapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: ClaudeRateLimitWindow(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)),
            sevenDay: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClaudeRateLimitSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testEncodesEpochSecondsNotISO8601() throws {
        let snapshot = ClaudeRateLimitSnapshot(
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fiveHour: nil,
            sevenDay: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["capturedAt"] as? Double, 1_700_000_000)
    }

    func testDecodesBridgeWrittenPartialWindowJSON() throws {
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """

        let decoded = try JSONDecoder().decode(ClaudeRateLimitSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.fiveHour, ClaudeRateLimitWindow(usedPercentage: 5.0, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertNil(decoded.sevenDay)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeRateLimitSnapshotTests`
Expected: FAIL to build — `cannot find 'ClaudeRateLimitSnapshot' in scope`

- [ ] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshot.swift`:

```swift
import Foundation

struct ClaudeRateLimitWindow: Codable, Equatable {
    let usedPercentage: Double
    let resetsAt: Date

    private enum CodingKeys: String, CodingKey {
        case usedPercentage
        case resetsAt
    }

    init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercentage = try container.decode(Double.self, forKey: .usedPercentage)
        let resetsAtEpochSeconds = try container.decode(Double.self, forKey: .resetsAt)
        resetsAt = Date(timeIntervalSince1970: resetsAtEpochSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usedPercentage, forKey: .usedPercentage)
        try container.encode(resetsAt.timeIntervalSince1970, forKey: .resetsAt)
    }
}

struct ClaudeRateLimitSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let capturedAt: Date
    let fiveHour: ClaudeRateLimitWindow?
    let sevenDay: ClaudeRateLimitWindow?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case capturedAt
        case fiveHour
        case sevenDay
    }

    init(schemaVersion: Int, capturedAt: Date, fiveHour: ClaudeRateLimitWindow?, sevenDay: ClaudeRateLimitWindow?) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let capturedAtEpochSeconds = try container.decode(Double.self, forKey: .capturedAt)
        capturedAt = Date(timeIntervalSince1970: capturedAtEpochSeconds)
        fiveHour = try container.decodeIfPresent(ClaudeRateLimitWindow.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(ClaudeRateLimitWindow.self, forKey: .sevenDay)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(capturedAt.timeIntervalSince1970, forKey: .capturedAt)
        try container.encodeIfPresent(fiveHour, forKey: .fiveHour)
        try container.encodeIfPresent(sevenDay, forKey: .sevenDay)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeRateLimitSnapshotTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshot.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotTests.swift
git commit -m "Add Codable Claude rate-limit snapshot model"
```

---

## Task 6: Swift snapshot reader

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotReaderTests.swift`

**Interfaces:**
- Consumes: `ClaudeRateLimitSnapshot` (Task 5).
- Produces: `ClaudeRateLimitSnapshotReader.init(fileManager: FileManager = .default)` (production), `ClaudeRateLimitSnapshotReader.init(fileURL: URL)` (test-injectable), `func readSnapshot() -> ClaudeRateLimitSnapshot?`.

- [ ] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotReaderTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeRateLimitSnapshotReaderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeRateLimitSnapshotReaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testReadSnapshotReturnsNilWhenFileMissing() {
        let reader = ClaudeRateLimitSnapshotReader(fileURL: tempDirectory.appendingPathComponent("missing.json"))

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotReturnsNilForMalformedJSON() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        try Data("not json".utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotReturnsNilForWrongSchemaVersion() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 2, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 10.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        XCTAssertNil(reader.readSnapshot())
    }

    func testReadSnapshotDecodesBothWindows() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, \
        "fiveHour": {"usedPercentage": 23.5, "resetsAt": 1800000000}, \
        "sevenDay": {"usedPercentage": 41.2, "resetsAt": 1800500000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        let snapshot = try XCTUnwrap(reader.readSnapshot())

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(snapshot.fiveHour, ClaudeRateLimitWindow(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertEqual(snapshot.sevenDay, ClaudeRateLimitWindow(usedPercentage: 41.2, resetsAt: Date(timeIntervalSince1970: 1_800_500_000)))
    }

    func testReadSnapshotDecodesPartialWindow() throws {
        let fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)
        let reader = ClaudeRateLimitSnapshotReader(fileURL: fileURL)

        let snapshot = try XCTUnwrap(reader.readSnapshot())

        XCTAssertNotNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.sevenDay)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeRateLimitSnapshotReaderTests`
Expected: FAIL to build — `cannot find 'ClaudeRateLimitSnapshotReader' in scope`

- [ ] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift`:

```swift
import Foundation

final class ClaudeRateLimitSnapshotReader {
    private let fileURL: URL
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.fileURL = support.appendingPathComponent("CodexUsageMonitor/claude-rate-limits.json")
        self.decoder = JSONDecoder()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.decoder = JSONDecoder()
    }

    /// Reads the bridge-written snapshot, or nil if it is missing, malformed,
    /// or on an unrecognized schema version. Never throws: this mirrors
    /// QuotaHistoryStore's read-only-best-effort behavior — a missing or
    /// corrupt snapshot must never crash or block the caller.
    func readSnapshot() -> ClaudeRateLimitSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(ClaudeRateLimitSnapshot.self, from: data),
              snapshot.schemaVersion == 1
        else { return nil }
        return snapshot
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeRateLimitSnapshotReaderTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full Swift test suite to confirm no regressions**

Run: `cd CodexUsageMonitor && swift test`
Expected: PASS (all existing tests plus the 8 new ones from Tasks 5–6)

- [ ] **Step 6: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRateLimitSnapshotReaderTests.swift
git commit -m "Add isolated reader for the Claude statusLine rate-limit snapshot"
```

---

## Task 7: Record evidence in the capability research gate

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md`
- Modify: `docs/product/planning-board.md`

**Interfaces:** None (documentation only).

- [ ] **Step 1: Update the capability research doc**

In `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md`, under "Gate before implementation," append a dated note under criterion 1 confirming the bridge/reader exist as prototyped evidence, e.g.:

```markdown
- **2026-07-20 implementation note:** the `ClaudeUsageBridge` script and `ClaudeRateLimitSnapshotReader` (see [statusLine usage bridge plan](2026-07-20-claude-statusline-usage-bridge.md)) implement and test Signal A end-to-end as an isolated component. No Settings UI, connection controller, or refresh cycle exists yet — criteria 3–5 remain open.
```

- [ ] **Step 2: Update the planning board**

In `docs/product/planning-board.md`, update the Claude local analytics/provider research row's "Next action" to reference the new plan and note the reader is implemented-but-unwired, and add the new plan to the "Active or decision-gated" list in the plan coverage index.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-07-20-claude-code-capability-research.md docs/product/planning-board.md
git commit -m "Record statusLine bridge prototype as gate evidence"
```

---

## No production UI wiring in this plan

This plan deliberately stops at an isolated, tested reader. It does not add a `QuotaMonitor`-style poller, does not publish `ClaudeRateLimitSnapshot` to any `ObservableObject`, and does not touch `ClaudeCodePreviewSettingsView.swift` or `AgentSettingsCatalog.swift`. Per the capability research's gate, criteria 3–5 (product-copy accuracy for what the number means, a single read-cycle owner with explicit teardown, and an explicit "not available" fallback state) need their own follow-up plan before any of that is authorized.

## Self-Review

**1. Spec coverage:** Every requirement from the 2026-07-20 research doc's "Authoritative-signal probe" section is covered: field-scoped extraction only (Task 1), zero-cost/passive capture (bridge design), owner-only atomic persistence (Task 2), a CLI matching Claude Code's `statusLine` contract (Task 3), safety-boundary documentation matching `UsageProbe`'s precedent (Task 4), and a Swift-side reader that never wires into product UI (Tasks 5–6). Gate bookkeeping is Task 7.

**2. Placeholder scan:** No `TBD`/`TODO`/"add appropriate error handling" language; every step has complete, runnable code; no step says "similar to Task N" without repeating the code.

**3. Type consistency:** `RateLimitSnapshot`/`RateLimitWindow` (Python, Task 1) and `ClaudeRateLimitSnapshot`/`ClaudeRateLimitWindow` (Swift, Tasks 5–6) use matching JSON key names (`schemaVersion`, `capturedAt`, `fiveHour`, `sevenDay`, `usedPercentage`, `resetsAt`) verified by the cross-language fixture in `ClaudeRateLimitSnapshotReaderTests.testReadSnapshotDecodesBothWindows`, which uses the exact shape `write_snapshot` produces.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-claude-statusline-usage-bridge.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
