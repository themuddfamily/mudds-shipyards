"""Focused tests for v3 cleanup digest reproducibility summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_summary_v3_validator as validator  # noqa: E402


def summary() -> dict:
    digest = "b" * 64
    canonical = "json-sorted-keys-utf8-lf-v1"
    runs = [{"run_id": "run-1", "summary_sha256": digest, "canonicalization": canonical, "tool_version": "cleanup-digest-v3", "evidence": "artifacts/audio/run-1.json", "independent": True}, {"run_id": "run-2", "summary_sha256": digest, "canonicalization": canonical, "tool_version": "cleanup-digest-v3", "evidence": "artifacts/audio/run-2.json", "independent": True}]
    return {"schema": "audio_cleanup_digest_reproducibility_summary_v3", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-repro-v3", "evidence_bundle": "artifacts/audio/repro-v3.json", "canonicalization": canonical, "native_audition": "OPEN", "claim": "AUTOMATED_REPRODUCIBILITY_V3_ONLY", "boundary_note": "Reproducibility does not establish native audibility.", "algorithm": "SHA-256", "summary_sha256": digest, "reproducible": True, "runs": runs}


class AudioCleanupDigestReproV3Tests(unittest.TestCase):
    def test_valid_canonicalized_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_canonicalization_must_match_runs(self):
        value = copy.deepcopy(summary())
        value["runs"][1]["canonicalization"] = "different"
        errors = validator.validate_summary(value)
        self.assertIn("runs canonicalization must match summary canonicalization", errors)

    def test_tool_versions_must_agree(self):
        value = copy.deepcopy(summary())
        value["runs"][1]["tool_version"] = "cleanup-digest-other"
        errors = validator.validate_summary(value)
        self.assertIn("runs tool_version values must agree", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(summary())
        value["native_audition"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
