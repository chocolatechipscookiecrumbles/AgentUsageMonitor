from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from datetime import datetime, timezone
from pathlib import Path

from .probe import CodexProbe
from .process import SafeCodexRunner


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="codex-probe",
        description="Inspect read-only Codex usage capabilities without starting a model turn.",
    )
    parser.add_argument("--codex", default="codex", help="Path to the Codex executable")
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=Path.home() / ".codex",
        help="Codex state directory; only allowlisted file metadata is inspected",
    )
    parser.add_argument("--json", action="store_true", help="Print the complete normalized JSON report")
    return parser.parse_args(arguments)


def main(arguments: Sequence[str] | None = None) -> int:
    options = parse_args(arguments)
    report = CodexProbe(SafeCodexRunner()).run(options.codex, options.codex_home)
    if options.json:
        print(json.dumps(report.to_dict(), indent=2, sort_keys=True))
    else:
        print(_summary(report.to_dict()))
    return 0


def _summary(report: dict[str, object]) -> str:
    rate_limits = report.get("rateLimits")
    if not isinstance(rate_limits, dict):
        return "Codex quota is unavailable. Run with --json for diagnostics."

    lines = [f"Codex plan: {rate_limits.get('planType') or 'Unknown'}"]
    credits = rate_limits.get("credits")
    if isinstance(credits, dict) and credits.get("hasCredits"):
        lines.append(f"Credits: {credits.get('balance') or 'Available'}")
    if isinstance(rate_limits.get("availableResetCredits"), int):
        lines.append(f"Available reset credits: {rate_limits['availableResetCredits']}")
    expiry_dates = rate_limits.get("resetCreditExpiresAt")
    if isinstance(expiry_dates, list):
        for expiry in expiry_dates:
            if isinstance(expiry, int):
                lines.append(f"  Reset credit expires: {_reset_text(expiry)}")
    primary = rate_limits.get("primary")
    secondary = rate_limits.get("secondary")
    weekly = _weekly_window(primary, secondary)
    short_term = _short_term_window(primary, secondary, weekly)
    if short_term is None and weekly is not None:
        lines.append("5-hour limit: not currently active")
    else:
        lines.extend(_window_summary("5-hour limit", short_term))
    lines.extend(_window_summary("Weekly limit", weekly))
    capability_detail = next(
        (item.get("detail") for item in report.get("capabilities", []) if isinstance(item, dict) and item.get("id") == "account-rate-limits"),
        None,
    )
    if isinstance(capability_detail, str):
        lines.append(f"Verification: {capability_detail}")
    return "\n".join(lines)


def _window_summary(label: str, window: object) -> list[str]:
    if not isinstance(window, dict):
        return [f"{label}: unavailable"]
    used = window.get("usedPercent")
    remaining = window.get("remainingPercent")
    reset = window.get("resetsAt")
    reset_text = _reset_text(reset) if isinstance(reset, int) else "unknown"
    return [f"{label}: {used}% used · {remaining}% remaining", f"  Resets: {reset_text}"]


def _weekly_window(primary: object, secondary: object) -> object:
    for window in (primary, secondary):
        if _duration_minutes(window) == 7 * 24 * 60:
            return window
    return secondary


def _short_term_window(primary: object, secondary: object, weekly: object) -> object:
    for window in (primary, secondary):
        if window is not weekly:
            return window
    return None


def _duration_minutes(window: object) -> int | None:
    if not isinstance(window, dict):
        return None
    duration = window.get("windowDurationMinutes")
    return duration if isinstance(duration, int) and not isinstance(duration, bool) else None


def _reset_text(timestamp: int) -> str:
    return datetime.fromtimestamp(timestamp, timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M %Z")
