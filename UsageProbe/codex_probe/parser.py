from __future__ import annotations

import json
import hashlib
from collections.abc import Iterable
from typing import Any

from .models import RateLimitSnapshot, RateLimitWindow, TokenUsageSummary


class AppServerError(RuntimeError):
    """A sanitized app-server protocol failure."""


def parse_rate_limits(lines: Iterable[str], request_id: int) -> RateLimitSnapshot:
    result = _result_for(lines, request_id)
    rate_limits_by_id = result.get("rateLimitsByLimitId")
    raw = rate_limits_by_id.get("codex") if isinstance(rate_limits_by_id, dict) else None
    raw = raw if isinstance(raw, dict) else result.get("rateLimits")
    if not isinstance(raw, dict):
        raise AppServerError(f"request {request_id} returned no rate-limit snapshot")
    credits = raw.get("credits") if isinstance(raw.get("credits"), dict) else {}
    reset_credits = result.get("rateLimitResetCredits")
    available_reset_credits = (
        _optional_int(reset_credits.get("availableCount"))
        if isinstance(reset_credits, dict)
        else None
    )
    reset_credit_details = reset_credits.get("credits") if isinstance(reset_credits, dict) else None
    reset_credit_expires_at = tuple(
        expiry
        for item in reset_credit_details
        if isinstance(item, dict) and (expiry := _optional_int(item.get("expiresAt"))) is not None
    ) if isinstance(reset_credit_details, list) else ()
    return RateLimitSnapshot(
        limit_id=_optional_string(raw.get("limitId")),
        plan_type=_optional_string(raw.get("planType")),
        primary=_window(raw.get("primary")),
        secondary=_window(raw.get("secondary")),
        has_credits=_optional_bool(credits.get("hasCredits")),
        credit_balance=_optional_string(credits.get("balance")),
        available_reset_credits=available_reset_credits,
        reset_credit_expires_at=reset_credit_expires_at,
    )


def parse_account_fingerprint(lines: Iterable[str], request_id: int) -> str | None:
    result = _result_for(lines, request_id)
    account = result.get("account")
    email = account.get("email") if isinstance(account, dict) else None
    if not isinstance(email, str) or not email:
        return None
    return hashlib.sha256(email.strip().lower().encode("utf-8")).hexdigest()[:16]


def parse_token_usage(lines: Iterable[str], request_id: int) -> TokenUsageSummary:
    result = _result_for(lines, request_id)
    raw = result.get("summary")
    if not isinstance(raw, dict):
        raise AppServerError(f"request {request_id} returned no token-usage summary")
    return TokenUsageSummary(
        lifetime_tokens=_optional_int(raw.get("lifetimeTokens")),
        current_streak_days=_optional_int(raw.get("currentStreakDays")),
        longest_streak_days=_optional_int(raw.get("longestStreakDays")),
        peak_daily_tokens=_optional_int(raw.get("peakDailyTokens")),
        longest_running_turn_seconds=_optional_int(raw.get("longestRunningTurnSec")),
    )


def _result_for(lines: Iterable[str], request_id: int) -> dict[str, Any]:
    for line in lines:
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(message, dict) or message.get("id") != request_id:
            continue
        if "error" in message:
            raise AppServerError(f"app-server request {request_id} failed")
        result = message.get("result")
        if isinstance(result, dict):
            return result
        raise AppServerError(f"app-server request {request_id} returned an invalid result")
    raise AppServerError(f"app-server response for request {request_id} was not found")


def _window(value: Any) -> RateLimitWindow | None:
    if not isinstance(value, dict) or not isinstance(value.get("usedPercent"), int):
        return None
    return RateLimitWindow(
        used_percent=value["usedPercent"],
        resets_at=_optional_int(value.get("resetsAt")),
        window_duration_minutes=_optional_int(value.get("windowDurationMins")),
    )


def _optional_int(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _optional_bool(value: Any) -> bool | None:
    return value if isinstance(value, bool) else None


def _optional_string(value: Any) -> str | None:
    return value if isinstance(value, str) else None
