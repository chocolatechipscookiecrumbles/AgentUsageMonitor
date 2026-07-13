import json
import os
import tempfile
import unittest
from pathlib import Path

from codex_probe.app_server import AppServerClient
from codex_probe.process import CommandResult, SafeCodexRunner, UnsafeCodexCommand


class RecordingRunner:
    def __init__(self) -> None:
        self.calls: list[tuple[str, tuple[str, ...], str | None, float]] = []

    def run(self, executable: str, arguments: tuple[str, ...], stdin: str | None, timeout: float) -> CommandResult:
        self.calls.append((executable, arguments, stdin, timeout))
        return CommandResult(
            exit_code=0,
            stdout="\n".join(
                (
                    '{"id":1,"result":{}}',
                    '{"id":2,"result":{"account":{}}}',
                    '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":7}}}}',
                    '{"id":4,"result":{"summary":{"lifetimeTokens":99}}}',
                )
            ),
            stderr="",
        )


class AppServerClientTests(unittest.TestCase):
    def test_sends_only_initialize_and_read_requests(self) -> None:
        runner = RecordingRunner()

        result = AppServerClient(runner).collect("/usr/local/bin/codex")

        self.assertEqual(result.rate_limits.primary.used_percent, 7)
        self.assertEqual(result.token_usage.lifetime_tokens, 99)
        executable, arguments, stdin, timeout = runner.calls[0]
        self.assertEqual(executable, "/usr/local/bin/codex")
        self.assertEqual(arguments, ("app-server", "--listen", "stdio://"))
        requests = [json.loads(line) for line in stdin.splitlines()]
        self.assertEqual(
            [request["method"] for request in requests],
            ["initialize", "initialized", "account/read", "account/rateLimits/read", "account/usage/read"],
        )
        self.assertTrue(requests[0]["params"]["capabilities"]["experimentalApi"])
        self.assertEqual(timeout, 15.0)

    def test_safe_runner_rejects_model_and_mutating_commands(self) -> None:
        runner = SafeCodexRunner()

        for arguments in (("exec", "hello"), ("logout",), ("account/rateLimitResetCredit/consume",)):
            with self.subTest(arguments=arguments):
                with self.assertRaises(UnsafeCodexCommand):
                    runner.run("codex", arguments, None, 1.0)

    def test_safe_runner_keeps_app_server_stdin_open_until_read_responses_arrive(self) -> None:
        server_source = '''#!/usr/bin/env python3
import json, select, sys
first = json.loads(sys.stdin.readline())
print(json.dumps({"id": first["id"], "result": {}}), flush=True)
second = json.loads(sys.stdin.readline())
third = json.loads(sys.stdin.readline())
readable, _, _ = select.select([sys.stdin], [], [], 0.1)
if readable and sys.stdin.read() == "":
    raise SystemExit(0)
print(json.dumps({"id": second["id"], "result": {"rateLimits": {"primary": {"usedPercent": 8}}}}), flush=True)
print(json.dumps({"id": third["id"], "result": {"summary": {"lifetimeTokens": 88}}}), flush=True)
'''
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "fake-codex"
            executable.write_text(server_source, encoding="utf-8")
            executable.chmod(0o755)
            stdin = "\n".join((
                '{"id":1,"method":"initialize","params":{}}',
                '{"id":2,"method":"account/rateLimits/read"}',
                '{"id":3,"method":"account/usage/read"}',
            )) + "\n"

            result = SafeCodexRunner().run(
                str(executable),
                ("app-server", "--listen", "stdio://"),
                stdin,
                2.0,
            )

        response_ids = [json.loads(line)["id"] for line in result.stdout.splitlines()]
        self.assertEqual(response_ids, [1, 2, 3])


if __name__ == "__main__":
    unittest.main()
