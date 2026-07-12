from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .app_server import AppServerClient, Runner
from .models import CapabilityResult, CapabilityStatus, LocalStateFile, ProbeReport
from .parser import AppServerError
from .process import CodexCommandError


class CodexProbe:
    _LOCAL_STATE_NAMES = (
        "state_5.sqlite",
        "logs_2.sqlite",
        "session_index.jsonl",
        "models_cache.json",
    )

    def __init__(self, runner: Runner) -> None:
        self._runner = runner

    def run(self, codex_path: str, codex_home: Path) -> ProbeReport:
        generated_at = datetime.now(timezone.utc)
        capabilities: list[CapabilityResult] = []

        try:
            version_result = self._runner.run(codex_path, ("--version",), None, 5.0)
        except CodexCommandError as error:
            return ProbeReport(
                generated_at=generated_at,
                codex_version=None,
                capabilities=(
                    CapabilityResult("codex-installation", CapabilityStatus.UNAVAILABLE, "local-cli", str(error)),
                ),
            )

        version = version_result.stdout.strip() if version_result.exit_code == 0 else None
        capabilities.append(
            CapabilityResult(
                "codex-installation",
                CapabilityStatus.LOCAL_ONLY if version else CapabilityStatus.ERROR,
                "local-cli",
                "Codex CLI version detected" if version else "Codex CLI version check failed",
            )
        )

        login = self._runner.run(codex_path, ("login", "status"), None, 5.0)
        login_status = f"{login.stdout}\n{login.stderr}".lower()
        authenticated = login.exit_code == 0 and "logged in" in login_status
        capabilities.append(
            CapabilityResult(
                "authentication",
                CapabilityStatus.LOCAL_ONLY if authenticated else CapabilityStatus.UNAVAILABLE,
                "codex-login-status",
                "Codex reports an authenticated session" if authenticated else "Codex is not authenticated",
            )
        )

        rate_limits = None
        token_usage = None
        if authenticated:
            try:
                app_result = AppServerClient(self._runner).collect(codex_path)
                rate_limits = app_result.rate_limits
                token_usage = app_result.token_usage
                quota_detail = (
                    "Three read-only app-server samples agreed"
                    if app_result.confirmation == "confirmed"
                    else "Accepted after rejecting a transient empty quota snapshot"
                    if app_result.confirmation == "confirmed-after-retry"
                    else "Quota samples disagreed; displaying the latest non-transient value as unconfirmed"
                    if app_result.confirmation == "unconfirmed-inconsistent"
                    else "Fresh quota samples were unsafe; displaying the last confirmed local snapshot"
                    if app_result.confirmation == "cached-last-known-good"
                    else "Only transient empty quota snapshots were returned"
                )
                capabilities.extend(
                    (
                        CapabilityResult(
                            "account-rate-limits",
                            CapabilityStatus.EXPERIMENTAL,
                            "codex-app-server",
                            quota_detail,
                        ),
                        CapabilityResult(
                            "account-token-usage",
                            CapabilityStatus.EXPERIMENTAL,
                            "codex-app-server",
                            quota_detail,
                        ),
                    )
                )
            except (AppServerError, CodexCommandError) as error:
                detail = str(error)
                capabilities.extend(
                    (
                        CapabilityResult("account-rate-limits", CapabilityStatus.ERROR, "codex-app-server", detail),
                        CapabilityResult("account-token-usage", CapabilityStatus.ERROR, "codex-app-server", detail),
                    )
                )
        else:
            capabilities.extend(
                (
                    CapabilityResult(
                        "account-rate-limits",
                        CapabilityStatus.UNAVAILABLE,
                        "codex-app-server",
                        "Authentication is required",
                    ),
                    CapabilityResult(
                        "account-token-usage",
                        CapabilityStatus.UNAVAILABLE,
                        "codex-app-server",
                        "Authentication is required",
                    ),
                )
            )

        local_state = tuple(self._local_state(codex_home))
        capabilities.append(
            CapabilityResult(
                "local-state-metadata",
                CapabilityStatus.LOCAL_ONLY if local_state else CapabilityStatus.UNAVAILABLE,
                "codex-home",
                f"Metadata available for {len(local_state)} allowlisted files",
            )
        )
        return ProbeReport(
            generated_at=generated_at,
            codex_version=version,
            capabilities=tuple(capabilities),
            rate_limits=rate_limits,
            token_usage=token_usage,
            local_state=local_state,
        )

    def _local_state(self, codex_home: Path) -> list[LocalStateFile]:
        files: list[LocalStateFile] = []
        for name in self._LOCAL_STATE_NAMES:
            path = codex_home / name
            try:
                stat = path.stat()
            except OSError:
                continue
            if not path.is_file():
                continue
            files.append(
                LocalStateFile(
                    name=name,
                    size_bytes=stat.st_size,
                    modified_at=datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc),
                )
            )
        return files
