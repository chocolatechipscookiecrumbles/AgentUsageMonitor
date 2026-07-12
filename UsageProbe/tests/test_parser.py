import unittest

from codex_probe.parser import AppServerError, parse_rate_limits, parse_token_usage


class AppServerParserTests(unittest.TestCase):
    def test_parses_rate_limit_windows_and_credits_amid_notifications(self) -> None:
        lines = [
            '{"method":"account/rateLimits/updated","params":{"ignored":true}}',
            '{"id":2,"result":{"rateLimits":{"planType":"pro","primary":{"usedPercent":37,"resetsAt":1700000100,"windowDurationMins":300},"secondary":{"usedPercent":12,"resetsAt":1700600000},"credits":{"hasCredits":true,"balance":"9.50"}}}}',
        ]

        snapshot = parse_rate_limits(lines, request_id=2)

        self.assertEqual(snapshot.plan_type, "pro")
        self.assertEqual(snapshot.primary.used_percent, 37)
        self.assertEqual(snapshot.primary.window_duration_minutes, 300)
        self.assertEqual(snapshot.secondary.used_percent, 12)
        self.assertTrue(snapshot.has_credits)
        self.assertEqual(snapshot.credit_balance, "9.50")

    def test_preserves_missing_optional_rate_limit_fields_as_none(self) -> None:
        snapshot = parse_rate_limits(
            ['{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":5}}}}'],
            request_id=2,
        )

        self.assertIsNone(snapshot.plan_type)
        self.assertIsNone(snapshot.primary.resets_at)
        self.assertIsNone(snapshot.secondary)

    def test_parses_token_usage_summary(self) -> None:
        usage = parse_token_usage(
            ['{"id":3,"result":{"summary":{"lifetimeTokens":1234,"currentStreakDays":4,"peakDailyTokens":500}}}'],
            request_id=3,
        )

        self.assertEqual(usage.lifetime_tokens, 1234)
        self.assertEqual(usage.current_streak_days, 4)
        self.assertEqual(usage.peak_daily_tokens, 500)

    def test_raises_sanitized_server_error(self) -> None:
        with self.assertRaisesRegex(AppServerError, "request 2 failed") as raised:
            parse_rate_limits(
                ['{"id":2,"error":{"code":-32000,"message":"secret-bearing detail"}}'],
                request_id=2,
            )

        self.assertNotIn("secret-bearing", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
