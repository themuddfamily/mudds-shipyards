"""Focused tests for audio cleanup summary digest metadata."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_summary_digest_validator as validator  # noqa: E402


def record() -> dict:
    return {"schema": "audio_cleanup_summary_digest_v1", "revision": "a" * 40, "digest_owner": "audio-evidence-owner", "summary_path": "artifacts/audio/cleanup-summary.json", "digest_evidence": "artifacts/audio/cleanup-summary.sha256.json", "native_audition": "OPEN", "claim": "AUTOMATED_DIGEST_ONLY", "boundary_note": "Digest identity does not establish native audibility.", "algorithm": "SHA-256", "summary_sha256": "b" * 64, "input_manifests": ["artifacts/audio/case-a.json", "artifacts/audio/case-b.json"], "input_count": 2, "canonicalization": "UTF-8 JSON sorted keys with LF endings", "reproducible": True}


class AudioCleanupSummaryDigestTests(unittest.TestCase):
    def test_valid_digest_record(self):
        self.assertEqual(validator.validate_digest(record()), [])

    def test_digest_algorithm_and_format_are_required(self):
        value = copy.deepcopy(record())
        value["algorithm"] = "MD5"
        value["summary_sha256"] = "bad"
        errors = validator.validate_digest(value)
        self.assertIn("algorithm must be SHA-256", errors)
        self.assertIn("summary_sha256 must be a lowercase 64-character digest", errors)

    def test_input_roster_count_and_reproducibility_are_required(self):
        value = copy.deepcopy(record())
        value["input_manifests"].append(value["input_manifests"][0])
        value["input_count"] = 3
        value["reproducible"] = False
        errors = validator.validate_digest(value)
        self.assertIn("input_manifests must be a non-empty unique list of paths", errors)
        self.assertIn("reproducible must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(record())
        value["native_audition"] = "PASS"
        errors = validator.validate_digest(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
