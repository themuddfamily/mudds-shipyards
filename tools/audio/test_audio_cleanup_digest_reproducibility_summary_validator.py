"""Focused tests for cleanup digest reproducibility summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_summary_validator as validator  # noqa: E402


def summary() -> dict:
    return {"schema": "audio_cleanup_digest_reproducibility_summary_v1", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-repro-summary-v1", "evidence_bundle": "artifacts/audio/repro-summary.json", "native_audition": "OPEN", "claim": "AUTOMATED_REPRODUCIBILITY_SUMMARY_ONLY", "boundary_note": "Digest agreement does not establish native audibility.", "totals": {"run_count": 2, "independent_run_count": 2, "matching_digest_count": 2, "input_agreement_count": 2}, "digest_status": "MATCHING", "input_status": "AGREED", "reproducible": True, "aggregation_evidence": "artifacts/audio/repro-summary-aggregation.json"}


class AudioCleanupDigestReproducibilitySummaryTests(unittest.TestCase):
    def test_valid_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_aggregate_counts_must_reconcile(self):
        value = copy.deepcopy(summary())
        value["totals"]["matching_digest_count"] = 1
        value["totals"]["input_agreement_count"] = 1
        errors = validator.validate_summary(value)
        self.assertIn("totals.matching_digest_count must equal run_count", errors)
        self.assertIn("totals.input_agreement_count must equal run_count", errors)

    def test_statuses_and_reproducible_flag_are_required(self):
        value = copy.deepcopy(summary())
        value["digest_status"] = "MISMATCH"
        value["input_status"] = "DRIFT"
        value["reproducible"] = False
        errors = validator.validate_summary(value)
        self.assertIn("digest_status must be MATCHING", errors)
        self.assertIn("input_status must be AGREED", errors)
        self.assertIn("reproducible must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(summary())
        value["native_audition"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
