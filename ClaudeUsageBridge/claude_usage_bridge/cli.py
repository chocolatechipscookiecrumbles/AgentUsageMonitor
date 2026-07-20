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
