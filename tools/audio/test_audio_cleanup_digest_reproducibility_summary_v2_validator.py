"""Focused tests for v2 cleanup digest reproducibility summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_summary_v2_validator as validator  # noqa: E402


def summary() -> dict:
    digest = "b" * 64
    input_digest = "c" * 64
    runs = [{"run_id": "run-1", "environment": "linux-godot", "summary_sha256": digest, "input_sha256": input_digest, "evidence": "artifacts/audio/run-1.json", "independent": True}, {"run_id": "run-2", "environment": "linux-godot-repeat", "summary_sha256": digest, "input_sha256": input_digest, "evidence": "artifacts/audio/run-2.json", "independent": True}]
    return {"schema": "audio_cleanup_digest_reproducibility_summary_v2", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-repro-v2", "evidence_bundle": "artifacts/audio/repro-v2.json", "native_audition": "OPEN", "claim": "AUTOMATED_REPRODUCIBILITY_V2_ONLY", "boundary_note": "Digest consensus does not establish native audibility.", "algorithm": "SHA-256", "summary_sha256": digest, "input_sha256": input_digest, "reproducible": True, "runs": runs}


class AudioCleanupDigestReproV2Tests(unittest.TestCase):
    def test_valid_per_run_v2_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_per_run_digest_agreement_is_required(self):
        value = copy.deepcopy(summary())
        value["runs"][1]["summary_sha256"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("runs.summary_sha256 digests must agree", errors)

    def test_summary_and_input_digest_must_match_rows(self):
        value = copy.deepcopy(summary())
        value["input_sha256"] = "e" * 64
        errors = validator.validate_summary(value)
        self.assertIn("input_sha256 must match the per-run input digest", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(summary())
        value["native_audition"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
