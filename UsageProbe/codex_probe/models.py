from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class CapabilityStatus(str, Enum):
    EXPERIMENTAL = "experimental"
    LOCAL_ONLY = "local-only"
    UNAVAILABLE = "unavailable"
    ERROR = "error"


@dataclass(frozen=True)
class CapabilityResult:
    id: str
    status: CapabilityStatus
    source: str
    detail: str

    def to_dict(self) -> dict[str, str]:
        return {
            "id": self.id,
            "status": self.status.value,
            "source": self.source,
            "detail": self.detail,
        }


@dataclass(frozen=True)
class RateLimitWindow:
    used_percent: int
    resets_at: int | None = None
    window_duration_minutes: int | None = None

    @property
    def remaining_percent(self) -> int:
        return max(0, 100 - self.used_percent)

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "usedPercent": self.used_percent,
            "remainingPercent": self.remaining_percent,
        }
        if self.resets_at is not None:
            result["resetsAt"] = self.resets_at
        if self.window_duration_minutes is not None:
            result["windowDurationMinutes"] = self.window_duration_minutes
        return result


@dataclass(frozen=True)
class RateLimitSnapshot:
    limit_id: str | None = None
    account_fingerprint: str | None = None
    plan_type: str | None = None
    primary: RateLimitWindow | None = None
    secondary: RateLimitWindow | None = None
    has_credits: bool | None = None
    credit_balance: str | None = None
    available_reset_credits: int | None = None
    reset_credit_expires_at: tuple[int, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {}
        if self.limit_id is not None:
            result["limitId"] = self.limit_id
        if self.account_fingerprint is not None:
            result["accountFingerprint"] = self.account_fingerprint
        if self.plan_type is not None:
            result["planType"] = self.plan_type
        if self.primary is not None:
            result["primary"] = self.primary.to_dict()
        if self.secondary is not None:
            result["secondary"] = self.secondary.to_dict()
        if self.has_credits is not None or self.credit_balance is not None:
            result["credits"] = {}
            if self.has_credits is not None:
                result["credits"]["hasCredits"] = self.has_credits
            if self.credit_balance is not None:
                result["credits"]["balance"] = self.credit_balance
        if self.available_reset_credits is not None:
            result["availableResetCredits"] = self.available_reset_credits
        if self.reset_credit_expires_at:
            result["resetCreditExpiresAt"] = list(self.reset_credit_expires_at)
        return result

    @classmethod
    def from_dict(cls, value: dict[str, Any]) -> "RateLimitSnapshot":
        credits = value.get("credits") if isinstance(value.get("credits"), dict) else {}
        reset_expiries = value.get("resetCreditExpiresAt")
        return cls(
            limit_id=_string(value.get("limitId")),
            account_fingerprint=_string(value.get("accountFingerprint")),
            plan_type=_string(value.get("planType")),
            primary=_window_from_dict(value.get("primary")),
            secondary=_window_from_dict(value.get("secondary")),
            has_credits=_bool(credits.get("hasCredits")),
            credit_balance=_string(credits.get("balance")),
            available_reset_credits=_integer(value.get("availableResetCredits")),
            reset_credit_expires_at=tuple(
                item for item in reset_expiries if _integer(item) is not None
            ) if isinstance(reset_expiries, list) else (),
        )


@dataclass(frozen=True)
class TokenUsageSummary:
    lifetime_tokens: int | None = None
    current_streak_days: int | None = None
    longest_streak_days: int | None = None
    peak_daily_tokens: int | None = None
    longest_running_turn_seconds: int | None = None

    def to_dict(self) -> dict[str, int]:
        values = {
            "lifetimeTokens": self.lifetime_tokens,
            "currentStreakDays": self.current_streak_days,
            "longestStreakDays": self.longest_streak_days,
            "peakDailyTokens": self.peak_daily_tokens,
            "longestRunningTurnSeconds": self.longest_running_turn_seconds,
        }
        return {key: value for key, value in values.items() if value is not None}


@dataclass(frozen=True)
class LocalStateFile:
    name: str
    size_bytes: int
    modified_at: datetime

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "sizeBytes": self.size_bytes,
            "modifiedAt": _iso8601(self.modified_at),
        }


@dataclass(frozen=True)
class ProbeReport:
    generated_at: datetime
    codex_version: str | None
    capabilities: tuple[CapabilityResult, ...]
    rate_limits: RateLimitSnapshot | None = None
    token_usage: TokenUsageSummary | None = None
    local_state: tuple[LocalStateFile, ...] = field(default_factory=tuple)
    schema_version: int = 1

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "schemaVersion": self.schema_version,
            "generatedAt": _iso8601(self.generated_at),
            "capabilities": [item.to_dict() for item in self.capabilities],
            "localState": [item.to_dict() for item in self.local_state],
        }
        if self.codex_version is not None:
            result["codexVersion"] = self.codex_version
        if self.rate_limits is not None:
            result["rateLimits"] = self.rate_limits.to_dict()
        if self.token_usage is not None:
            result["tokenUsage"] = self.token_usage.to_dict()
        return result


def _iso8601(value: datetime) -> str:
    normalized = value.astimezone(timezone.utc).replace(microsecond=0)
    return normalized.isoformat().replace("+00:00", "Z")


def _window_from_dict(value: object) -> RateLimitWindow | None:
    if not isinstance(value, dict) or (used_percent := _integer(value.get("usedPercent"))) is None:
        return None
    return RateLimitWindow(
        used_percent=used_percent,
        resets_at=_integer(value.get("resetsAt")),
        window_duration_minutes=_integer(value.get("windowDurationMinutes")),
    )


def _integer(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _bool(value: object) -> bool | None:
    return value if isinstance(value, bool) else None


def _string(value: object) -> str | None:
    return value if isinstance(value, str) else None
