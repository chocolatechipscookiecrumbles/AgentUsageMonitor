from __future__ import annotations

import json
import os
import stat
import tempfile
from pathlib import Path

from .models import RateLimitSnapshot


def default_output_path() -> Path:
    return Path.home() / "Library" / "Application Support" / "CodexUsageMonitor" / "claude-rate-limits.json"


def write_snapshot(snapshot: RateLimitSnapshot, output_path: Path) -> None:
    """Atomically write the snapshot with owner-only directory/file permissions."""
    directory = output_path.parent
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, stat.S_IRWXU)
    fd, temp_name = tempfile.mkstemp(dir=directory, prefix=".claude-rate-limits-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(snapshot.to_dict(), handle, sort_keys=True)
        os.chmod(temp_name, stat.S_IRUSR | stat.S_IWUSR)
        os.replace(temp_name, output_path)
    except BaseException:
        os.unlink(temp_name)
        raise
