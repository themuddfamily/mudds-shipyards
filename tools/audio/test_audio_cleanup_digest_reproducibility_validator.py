"""Focused tests for cleanup digest reproducibility evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_validator as validator  # noqa: E402


def record() -> dict:
    inputs = ["artifacts/audio/case-a.json", "artifacts/audio/case-b.json"]
    digest = "b" * 64
    return {"schema": "audio_cleanup_digest_reproducibility_v1", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-summary-v1", "evidence_bundle": "artifacts/audio/repro.json", "native_audition": "OPEN", "claim": "AUTOMATED_REPRODUCIBILITY_ONLY", "boundary_note": "Digest reproducibility does not establish native audibility.", "algorithm": "SHA-256", "input_manifests": inputs, "reproducible": True, "runs": [{"run_id": "run-1", "sha256": digest, "input_manifests": inputs, "evidence": "artifacts/audio/run-1.json", "independent": True}, {"run_id": "run-2", "sha256": digest, "input_manifests": inputs, "evidence": "artifacts/audio/run-2.json", "independent": True}]}


class AudioCleanupDigestReproducibilityTests(unittest.TestCase):
    def test_valid_independent_matching_runs(self):
        self.assertEqual(validator.validate_reproducibility(record()), [])

    def test_digest_mismatch_breaks_reproducibility(self):
        value = copy.deepcopy(record())
        value["runs"][1]["sha256"] = "c" * 64
        value["reproducible"] = False
        errors = validator.validate_reproducibility(value)
        self.assertIn("runs sha256 digests must match", errors)

    def test_each_run_must_match_inputs_and_be_independent(self):
        value = copy.deepcopy(record())
        value["runs"][1]["input_manifests"] = ["artifacts/audio/other.json"]
        value["runs"][0]["independent"] = False
        errors = validator.validate_reproducibility(value)
        self.assertIn("runs[1].input_manifests must match record input_manifests", errors)
        self.assertIn("runs[0].independent must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(record())
        value["native_audition"] = "PASS"
        errors = validator.validate_reproducibility(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
