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
