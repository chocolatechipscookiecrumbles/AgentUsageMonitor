import unittest
from pathlib import Path

from codex_probe.cli import _summary, parse_args


class CLIArgumentsTests(unittest.TestCase):
    def test_uses_safe_defaults(self) -> None:
        arguments = parse_args([])

        self.assertEqual(arguments.codex, "codex")
        self.assertEqual(arguments.codex_home, Path.home() / ".codex")

    def test_accepts_codex_and_home_overrides(self) -> None:
        arguments = parse_args(["--codex", "/opt/codex", "--codex-home", "/tmp/codex-home"])

        self.assertEqual(arguments.codex, "/opt/codex")
        self.assertEqual(arguments.codex_home, Path("/tmp/codex-home"))

    def test_rejects_unknown_arguments(self) -> None:
        with self.assertRaises(SystemExit):
            parse_args(["--run-prompt"])

    def test_summarizes_a_weekly_only_primary_window(self) -> None:
        summary = _summary(
            {
                "rateLimits": {
                    "primary": {
                        "usedPercent": 1,
                        "remainingPercent": 99,
                        "resetsAt": 1784513329,
                        "windowDurationMinutes": 10080,
                    }
                }
            }
        )

        self.assertIn("5-hour limit: not currently active", summary)
        self.assertIn("Weekly limit: 1% used · 99% remaining", summary)
        self.assertNotIn("5-hour limit: 1% used", summary)


if __name__ == "__main__":
    unittest.main()
