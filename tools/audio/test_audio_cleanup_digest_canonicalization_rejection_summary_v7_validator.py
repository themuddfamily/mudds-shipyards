"""Focused tests for v7 canonicalization rejection summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_canonicalization_rejection_summary_v7_validator as validator  # noqa: E402


def summary() -> dict:
    accepted_digest = "a" * 64
    rejected = [{"rejection_id": "reject-1", "canonicalization": "json-unsorted", "digest": "b" * 64, "rejected": True, "reason": "keys were not canonicalized", "evidence": "artifacts/audio/reject-1.json"}]
    return {"schema": "audio_cleanup_digest_canonicalization_rejection_summary_v7", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-canon-v7", "evidence_bundle": "artifacts/audio/canon-v7.json", "claim": "AUTOMATED_CANONICALIZATION_REJECTION_ONLY", "boundary_note": "Canonicalization rejection does not establish native audibility.", "accepted_canonicalization": "json-sorted-v1", "accepted_digest": accepted_digest, "accepted": {"canonicalization": "json-sorted-v1", "digest": accepted_digest, "rejected": False, "evidence": "artifacts/audio/accepted.json"}, "rejected": rejected, "rejection_count": 1, "rejection_pass": True}


class AudioCleanupCanonicalizationRejectionV7Tests(unittest.TestCase):
    def test_valid_rejection_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_accepted_canonicalization_must_be_frozen(self):
        value = copy.deepcopy(summary())
        value["accepted_canonicalization"] = "json-unsorted"
        errors = validator.validate_summary(value)
        self.assertIn("accepted_canonicalization must be json-sorted-v1", errors)

    def test_nonaccepted_rows_must_be_rejected(self):
        value = copy.deepcopy(summary())
        value["rejected"][0]["canonicalization"] = "json-sorted-v1"
        value["rejected"][0]["rejected"] = False
        errors = validator.validate_summary(value)
        self.assertIn("rejected[0].canonicalization must be rejected as non-accepted", errors)
        self.assertIn("rejected[0].rejected must be true", errors)

    def test_rejection_count_and_digest_format_are_required(self):
        value = copy.deepcopy(summary())
        value["rejection_count"] = 2
        value["rejected"][0]["digest"] = "bad"
        errors = validator.validate_summary(value)
        self.assertIn("rejection_count must match rejected length", errors)
        self.assertIn("rejected[0].digest must be a lowercase 64-character digest", errors)


if __name__ == "__main__":
    unittest.main()
