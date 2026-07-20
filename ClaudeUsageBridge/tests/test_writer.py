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
