import unittest
from pathlib import Path

from codex_probe.cli import parse_args


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


if __name__ == "__main__":
    unittest.main()
