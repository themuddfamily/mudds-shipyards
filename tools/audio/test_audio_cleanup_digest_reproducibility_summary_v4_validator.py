"""Focused tests for v4 cleanup digest reproducibility summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_summary_v4_validator as validator  # noqa: E402


def summary() -> dict:
    inputs = ["artifacts/audio/a.json", "artifacts/audio/b.json"]
    digest = "b" * 64
    runs = [{"run_id": "run-1", "timestamp_utc": "2026-08-20T12:00:00Z", "input_manifests": inputs, "summary_sha256": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/run-1.json", "independent": True}, {"run_id": "run-2", "timestamp_utc": "2026-08-20T12:01:00Z", "input_manifests": inputs, "summary_sha256": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/run-2.json", "independent": True}]
    return {"schema": "audio_cleanup_digest_reproducibility_summary_v4", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-repro-v4", "evidence_bundle": "artifacts/audio/repro-v4.json", "canonicalization": "json-sorted-v1", "native_audition": "OPEN", "claim": "AUTOMATED_REPRODUCIBILITY_V4_ONLY", "boundary_note": "Digest reproducibility does not establish native audibility.", "algorithm": "SHA-256", "summary_sha256": digest, "input_manifests": inputs, "reproducible": True, "runs": runs}


class AudioCleanupDigestReproV4Tests(unittest.TestCase):
    def test_valid_ordered_input_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_input_roster_must_be_ordered_and_match_runs(self):
        value = copy.deepcopy(summary())
        value["input_manifests"] = list(reversed(value["input_manifests"]))
        errors = validator.validate_summary(value)
        self.assertIn("input_manifests must be lexicographically ordered", errors)
        self.assertTrue(any("input_manifests must match ordered summary roster" in error for error in errors))

    def test_run_timestamps_must_be_unique(self):
        value = copy.deepcopy(summary())
        value["runs"][1]["timestamp_utc"] = value["runs"][0]["timestamp_utc"]
        errors = validator.validate_summary(value)
        self.assertIn("runs[1].timestamp_utc is duplicated", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(summary())
        value["native_audition"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
