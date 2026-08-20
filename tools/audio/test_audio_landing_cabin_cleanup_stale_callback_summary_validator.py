"""Focused tests for stale-callback cleanup summary evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_cleanup_stale_callback_summary_validator as validator  # noqa: E402


def summary() -> dict:
    return {"schema": "audio_landing_cabin_cleanup_stale_callback_summary_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/cleanup-summary.json", "native_audition": "OPEN", "claim": "AUTOMATED_SUMMARY_ONLY", "boundary_note": "No native audition has occurred.", "cases": sorted(validator.CASES), "totals": {"case_count": 4, "callback_count": 12, "rejected_count": 12, "cleanup_count": 12, "zero_voice_count": 12}, "aggregation_evidence": "artifacts/audio/cleanup-summary-aggregation.json"}


class AudioLandingCabinCleanupSummaryTests(unittest.TestCase):
    def test_valid_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_totals_must_reconcile(self):
        value = copy.deepcopy(summary())
        value["totals"]["rejected_count"] = 11
        value["totals"]["zero_voice_count"] = 10
        errors = validator.validate_summary(value)
        self.assertIn("totals.rejected_count must equal callback_count", errors)
        self.assertIn("totals.zero_voice_count must equal cleanup_count", errors)

    def test_case_roster_and_count_are_required(self):
        value = copy.deepcopy(summary())
        value["cases"] = ["landing_abort", "landing_abort"]
        errors = validator.validate_summary(value)
        self.assertIn("cases must exactly cover landing_abort, landing_complete, cabin_exit, and detach_reentry", errors)
        self.assertIn("cases must not contain duplicates", errors)
        self.assertIn("totals.case_count must match cases length", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(summary())
        value["native_audition"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
