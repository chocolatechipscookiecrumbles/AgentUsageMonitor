import tempfile
import unittest
from pathlib import Path

from codex_probe.probe import CodexProbe
from codex_probe.process import CommandResult


class FakeRunner:
    def __init__(self, logged_in: bool = True, app_server_exit: int = 0) -> None:
        self.logged_in = logged_in
        self.app_server_exit = app_server_exit

    def run(self, executable: str, arguments: tuple[str, ...], stdin: str | None, timeout: float) -> CommandResult:
        if arguments == ("--version",):
            return CommandResult(0, "codex-cli 0.144.0\n", "")
        if arguments == ("login", "status"):
            text = "Logged in using ChatGPT\n" if self.logged_in else "Not logged in\n"
            return CommandResult(0 if self.logged_in else 1, "", text)
        if arguments == ("app-server", "--listen", "stdio://"):
            if self.app_server_exit:
                return CommandResult(self.app_server_exit, "", "sensitive failure")
            return CommandResult(
                0,
                '\n'.join((
                    '{"id":1,"result":{}}',
                    '{"id":2,"result":{"account":{}}}',
                    '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":22}}}}',
                    '{"id":4,"result":{"summary":{"lifetimeTokens":321}}}',
                )),
                "",
            )
        raise AssertionError(f"unexpected arguments: {arguments}")


class CodexProbeTests(unittest.TestCase):
    def test_classifies_live_protocol_as_experimental(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / "state_5.sqlite").write_bytes(b"state")
            (home / "auth.json").write_text("TOP-SECRET", encoding="utf-8")

            report = CodexProbe(FakeRunner()).run("codex", home)

        statuses = {item.id: item.status.value for item in report.capabilities}
        self.assertEqual(statuses["codex-installation"], "local-only")
        self.assertEqual(statuses["authentication"], "local-only")
        self.assertEqual(statuses["account-rate-limits"], "experimental")
        self.assertEqual(statuses["account-token-usage"], "experimental")
        self.assertEqual(report.rate_limits.primary.used_percent, 22)
        self.assertEqual(report.token_usage.lifetime_tokens, 321)
        self.assertEqual([item.name for item in report.local_state], ["state_5.sqlite"])
        self.assertNotIn("TOP-SECRET", str(report.to_dict()))

    def test_logged_out_state_does_not_attempt_app_server(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = CodexProbe(FakeRunner(logged_in=False)).run("codex", Path(directory))

        statuses = {item.id: item.status.value for item in report.capabilities}
        self.assertEqual(statuses["authentication"], "unavailable")
        self.assertEqual(statuses["account-rate-limits"], "unavailable")
        self.assertIsNone(report.rate_limits)

    def test_app_server_failure_is_sanitized(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            report = CodexProbe(FakeRunner(app_server_exit=1)).run("codex", Path(directory))

        quota = next(item for item in report.capabilities if item.id == "account-rate-limits")
        self.assertEqual(quota.status.value, "error")
        self.assertNotIn("sensitive", quota.detail)


if __name__ == "__main__":
    unittest.main()
