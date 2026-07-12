import unittest
from datetime import datetime, timezone

from codex_probe.models import CapabilityResult, CapabilityStatus, ProbeReport


class ProbeReportTests(unittest.TestCase):
    def test_serializes_versioned_report_without_raw_payload(self) -> None:
        report = ProbeReport(
            generated_at=datetime(2023, 11, 14, 22, 13, 20, tzinfo=timezone.utc),
            codex_version="codex-cli 1.2.3",
            capabilities=(
                CapabilityResult(
                    id="account-rate-limits",
                    status=CapabilityStatus.EXPERIMENTAL,
                    source="codex-app-server",
                    detail="Read-only protocol available",
                ),
            ),
        )

        payload = report.to_dict()

        self.assertEqual(payload["schemaVersion"], 1)
        self.assertEqual(payload["generatedAt"], "2023-11-14T22:13:20Z")
        self.assertEqual(payload["capabilities"][0]["status"], "experimental")
        self.assertNotIn("rawPayload", payload)


if __name__ == "__main__":
    unittest.main()
