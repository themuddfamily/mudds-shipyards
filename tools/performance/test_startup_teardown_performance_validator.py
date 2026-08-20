"""Focused tests for native startup/load/teardown evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import startup_teardown_performance_validator as validator  # noqa: E402


def report():
    summary = {"count": 10, "p50": 10.0, "p95": 15.0, "p99": 20.0, "max": 25.0}
    return {
        "schema_version": 1,
        "report_kind": validator.REPORT_KIND,
        "source": {"git_sha": "b" * 40, "git_dirty": False},
        "native_evidence": {
            "available": True,
            "platform": "windows-x86_64",
            "software_renderer": False,
            "hardware": "mid-range target GPU",
            "os_build": "Windows 11 25H2",
        },
        "measurement_provenance": {"harness": "native-benchmark-runner 1.0", "capture_id": "startup-20260820-01"},
        "long_session_seconds": 1800,
        "warmup_seconds": 60,
        "summaries": {name: copy.deepcopy(summary) for name in validator.SUMMARY_FIELDS},
        "target_profile": {"budgets": {
            "startup_p95_ms": 2_000, "startup_p99_ms": 3_000,
            "load_p95_ms": 1_000, "load_p99_ms": 2_000,
            "teardown_p95_ms": 1_000, "teardown_p99_ms": 2_000,
            "max_long_session_growth_bytes": 30,
        }},
    }


class StartupTeardownValidatorTests(unittest.TestCase):
    def test_valid_native_report(self):
        self.assertEqual(validator.validate_report(report()), [])

    def test_native_provenance_is_required(self):
        value = report()
        value["native_evidence"]["software_renderer"] = True
        value["measurement_provenance"].pop("capture_id")
        errors = validator.validate_report(value)
        self.assertIn("native_evidence.software_renderer must be false", errors)
        self.assertIn("measurement_provenance.capture_id is required", errors)

    def test_percentiles_are_monotonic(self):
        value = report()
        value["summaries"]["load_ms"]["p99"] = 1.0
        self.assertIn("summaries.load_ms percentiles are not monotonic", validator.validate_report(value))

    def test_all_lifecycle_budgets_are_checked(self):
        value = report()
        value["summaries"]["startup_ms"]["p99"] = 3_001
        value["summaries"]["load_ms"]["p95"] = 1_001
        value["summaries"]["teardown_ms"]["p99"] = 2_001
        value["summaries"]["long_session_growth_bytes"]["p99"] = 31
        errors = validator.validate_report(value)
        self.assertIn("summaries.startup_ms.p99 exceeds budget", errors)
        self.assertIn("summaries.load_ms.p95 exceeds budget", errors)
        self.assertIn("summaries.teardown_ms.p99 exceeds budget", errors)
        self.assertIn("summaries.long_session_growth_bytes.p99 exceeds budget", errors)

    def test_invalid_session_window_fails_closed(self):
        value = report()
        value["warmup_seconds"] = value["long_session_seconds"]
        self.assertIn("warmup_seconds must be less than long_session_seconds", validator.validate_report(value))


if __name__ == "__main__":
    unittest.main()
