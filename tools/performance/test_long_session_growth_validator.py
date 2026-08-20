"""Focused tests for native long-session performance evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import long_session_growth_validator as validator  # noqa: E402


def report():
    summary = {"count": 100, "p50": 10.0, "p95": 15.0, "p99": 20.0, "max": 25.0}
    return {
        "schema_version": 1,
        "report_kind": validator.REPORT_KIND,
        "source": {"git_sha": "a" * 40, "git_dirty": False},
        "native_evidence": {"available": True, "platform": "windows-x86_64", "software_renderer": False, "hardware": "target GPU"},
        "duration_seconds": 1800,
        "reentry_cycles": 10,
        "summaries": {name: copy.deepcopy(summary) for name in validator.SUMMARY_FIELDS},
        "growth": {
            "ram_bytes": {"unit": "bytes", "baseline": 1_000, "end": 1_020, "peak": 1_100},
            "vram_bytes": {"unit": "bytes", "baseline": 2_000, "end": 2_010, "peak": 2_050},
        },
        "startup_time_ms": 900,
        "voice_memory_bytes": 1_000,
        "target_profile": {"budgets": {
            "frame_p95_ms": 16.7, "frame_p99_ms": 33.3, "gpu_p95_ms": 16.0,
            "startup_ms": 2_000, "max_ram_growth_bytes": 200, "max_vram_growth_bytes": 100,
            "max_audio_voices": 30, "max_voice_memory_bytes": 2_000,
        }},
    }


class LongSessionGrowthValidatorTests(unittest.TestCase):
    def test_valid_native_record(self):
        self.assertEqual(validator.validate_report(report()), [])

    def test_missing_native_evidence_fails_closed(self):
        value = report()
        value.pop("native_evidence")
        self.assertIn("native_evidence.available must be true", validator.validate_report(value))

    def test_software_renderer_is_not_native(self):
        value = report()
        value["native_evidence"]["software_renderer"] = True
        self.assertIn("native_evidence.software_renderer must be false", validator.validate_report(value))

    def test_percentile_order_and_growth_are_checked(self):
        value = report()
        value["summaries"]["frame_time_ms"]["p99"] = 9.0
        value["growth"]["ram_bytes"]["peak"] = 2_000
        errors = validator.validate_report(value)
        self.assertIn("summaries.frame_time_ms percentiles are not monotonic", errors)
        self.assertIn("growth.ram_bytes exceeds budget", errors)

    def test_startup_and_voice_budgets_are_checked(self):
        value = report()
        value["startup_time_ms"] = 3_000
        value["summaries"]["audio_voices"]["max"] = 31
        errors = validator.validate_report(value)
        self.assertIn("startup_time_ms exceeds budget", errors)
        self.assertIn("audio_voices.max exceeds budget", errors)

    def test_missing_summary_and_budget_fail_closed(self):
        value = report()
        del value["summaries"]["vram_bytes"]
        del value["target_profile"]["budgets"]["max_vram_growth_bytes"]
        errors = validator.validate_report(value)
        self.assertIn("summaries.vram_bytes must be an object", errors)
        self.assertIn("target budgets.max_vram_growth_bytes must be non-negative", errors)


if __name__ == "__main__":
    unittest.main()
