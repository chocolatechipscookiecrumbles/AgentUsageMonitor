from __future__ import annotations

import json
import time
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from typing import Protocol

from .models import RateLimitSnapshot, RateLimitWindow, TokenUsageSummary
from .parser import AppServerError, parse_account_fingerprint, parse_rate_limits, parse_token_usage
from .process import CommandResult
from .quota_state import QuotaStateStore


class Runner(Protocol):
    def run(
        self,
        executable: str,
        arguments: tuple[str, ...],
        stdin: str | None,
        timeout: float,
    ) -> CommandResult: ...


@dataclass(frozen=True)
class AppServerResult:
    rate_limits: RateLimitSnapshot
    token_usage: TokenUsageSummary
    confirmation: str


@dataclass(frozen=True)
class AppServerSample:
    rate_limits: RateLimitSnapshot
    token_usage: TokenUsageSummary
    collected_at: datetime


class AppServerClient:
    def __init__(self, runner: Runner, timeout: float = 15.0, state_store: QuotaStateStore | None = None) -> None:
        self._runner = runner
        self._timeout = timeout
        self._state_store = state_store or QuotaStateStore()

    def collect(self, executable: str) -> AppServerResult:
        samples: list[AppServerSample] = []
        for attempt in range(3):
            samples.append(self._collect_once(executable))
            if attempt < 2:
                time.sleep(1)

        accepted = [sample for sample in samples if not _is_transient_empty_snapshot(sample.rate_limits, sample.collected_at)]
        if len(accepted) >= 2 and _matching_samples(accepted):
            rate_limits, token_usage = accepted[-1].rate_limits, accepted[-1].token_usage
            self._state_store.save(rate_limits)
            confirmation = "confirmed-after-retry" if len(accepted) != len(samples) else "confirmed"
        elif accepted:
            rate_limits, token_usage = accepted[-1].rate_limits, accepted[-1].token_usage
            stored = self._state_store.load()
            if _matches_stored_account(stored, rate_limits):
                rate_limits = stored.rate_limits
                confirmation = "cached-last-known-good"
            else:
                confirmation = "unconfirmed-inconsistent"
        else:
            rate_limits, token_usage = samples[-1].rate_limits, samples[-1].token_usage
            stored = self._state_store.load()
            if _matches_stored_account(stored, rate_limits):
                rate_limits = stored.rate_limits
                confirmation = "cached-last-known-good"
            else:
                confirmation = "unconfirmed-transient"
        return AppServerResult(rate_limits, token_usage, confirmation)

    def _collect_once(self, executable: str) -> AppServerSample:
        requests = (
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "codex-capability-probe", "version": "0.1.0"},
                    "capabilities": {"experimentalApi": True},
                },
            },
            {"method": "initialized", "params": {}},
            {"id": 2, "method": "account/read", "params": {"refreshToken": False}},
            {"id": 3, "method": "account/rateLimits/read"},
            {"id": 4, "method": "account/usage/read"},
        )
        stdin = "\n".join(json.dumps(item, separators=(",", ":")) for item in requests) + "\n"
        command = self._runner.run(
            executable,
            ("app-server", "--listen", "stdio://"),
            stdin,
            self._timeout,
        )
        if command.exit_code != 0:
            raise AppServerError(f"app-server exited with status {command.exit_code}")
        lines = command.stdout.splitlines()
        return AppServerSample(
            rate_limits=replace(
                parse_rate_limits(lines, request_id=3),
                account_fingerprint=parse_account_fingerprint(lines, request_id=2),
            ),
            token_usage=parse_token_usage(lines, request_id=4),
            collected_at=datetime.now(timezone.utc),
        )


def _is_transient_empty_snapshot(snapshot: RateLimitSnapshot, collected_at: datetime) -> bool:
    primary = snapshot.primary
    secondary = snapshot.secondary
    if primary is None or secondary is None or primary.resets_at is None or primary.window_duration_minutes is None:
        return False
    expected_reset = collected_at.timestamp() + primary.window_duration_minutes * 60
    is_newly_anchored = abs(primary.resets_at - expected_reset) <= 90
    return primary.used_percent <= 5 and secondary.used_percent <= 5 and is_newly_anchored


def _matching_samples(samples: list[AppServerSample]) -> bool:
    first = samples[0].rate_limits
    if first.account_fingerprint is None or first.limit_id != "codex":
        return False
    for sample in samples[1:]:
        snapshot = sample.rate_limits
        if snapshot.account_fingerprint != first.account_fingerprint or snapshot.limit_id != first.limit_id:
            return False
        if not _matching_windows(first.primary, snapshot.primary):
            return False
        if not _matching_windows(first.secondary, snapshot.secondary):
            return False
    return True


def _matches_stored_account(stored: object, rate_limits: RateLimitSnapshot) -> bool:
    return (
        stored is not None
        and getattr(stored, "rate_limits").account_fingerprint == rate_limits.account_fingerprint
        and rate_limits.account_fingerprint is not None
        and rate_limits.limit_id == "codex"
    )


def _matching_windows(first: object, second: object) -> bool:
    if not isinstance(first, type(second)) or first is None:
        return first is second
    if not isinstance(first, RateLimitWindow) or not isinstance(second, RateLimitWindow):
        return False
    if first.resets_at is None or second.resets_at is None:
        return first.resets_at == second.resets_at and abs(first.used_percent - second.used_percent) <= 5
    return abs(first.resets_at - second.resets_at) <= 120 and abs(first.used_percent - second.used_percent) <= 5
