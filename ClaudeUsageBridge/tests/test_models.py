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
