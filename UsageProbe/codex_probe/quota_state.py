from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from .models import RateLimitSnapshot


@dataclass(frozen=True)
class StoredQuota:
    saved_at: datetime
    rate_limits: RateLimitSnapshot


class QuotaStateStore:
    """Persists only the last confirmed, non-secret quota snapshot."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or Path.home() / ".codex-usage-probe" / "last-known-good.json"

    def load(self) -> StoredQuota | None:
        try:
            value = json.loads(self._path.read_text(encoding="utf-8"))
            saved_at = datetime.fromisoformat(value["savedAt"].replace("Z", "+00:00"))
            rate_limits = RateLimitSnapshot.from_dict(value["rateLimits"])
        except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
            return None
        if rate_limits.account_fingerprint is None or rate_limits.limit_id != "codex":
            return None
        return StoredQuota(saved_at=saved_at, rate_limits=rate_limits)

    def save(self, rate_limits: RateLimitSnapshot) -> None:
        if rate_limits.account_fingerprint is None or rate_limits.limit_id != "codex":
            return
        self._path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        payload = {
            "schemaVersion": 1,
            "savedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "rateLimits": rate_limits.to_dict(),
        }
        self._path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        self._path.chmod(0o600)
