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
