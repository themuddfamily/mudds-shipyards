"""Focused tests for v8 cleanup-digest rejection evidence linkage."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_rejection_evidence_linkage_summary_v8_validator as validator  # noqa: E402


def summary() -> dict:
    accepted_digest = "a" * 64
    return {"schema": "audio_cleanup_digest_rejection_evidence_linkage_summary_v8", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-linkage-v8", "evidence_bundle": "artifacts/audio/linkage-v8.json", "claim": "AUTOMATED_REJECTION_LINKAGE_ONLY", "boundary_note": "Evidence linkage does not establish native audibility.", "accepted_digest": accepted_digest, "evidence_records": [{"evidence_id": "ev-1", "path": "artifacts/audio/accepted.json", "sha256": "b" * 64}, {"evidence_id": "ev-2", "path": "artifacts/audio/rejected.json", "sha256": "c" * 64}], "decisions": [{"decision_id": "decision-1", "result": "ACCEPTED", "digest": accepted_digest, "evidence_id": "ev-1", "reason": "canonical input"}, {"decision_id": "decision-2", "result": "REJECTED", "digest": "d" * 64, "evidence_id": "ev-2", "reason": "non-canonical input"}], "linkage_pass": True}


class AudioCleanupRejectionLinkageV8Tests(unittest.TestCase):
    def test_valid_linked_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_decision_must_reference_evidence(self):
        value = copy.deepcopy(summary())
        value["decisions"][1]["evidence_id"] = "missing"
        errors = validator.validate_summary(value)
        self.assertIn("decisions[1].evidence_id must reference evidence_records", errors)

    def test_accepted_digest_must_match_summary(self):
        value = copy.deepcopy(summary())
        value["decisions"][0]["digest"] = "e" * 64
        errors = validator.validate_summary(value)
        self.assertIn("decisions[0].digest must match accepted_digest", errors)

    def test_duplicate_evidence_identity_is_rejected(self):
        value = copy.deepcopy(summary())
        value["evidence_records"][1]["evidence_id"] = "ev-1"
        errors = validator.validate_summary(value)
        self.assertIn("evidence_records[1].evidence_id is duplicated", errors)


if __name__ == "__main__":
    unittest.main()
