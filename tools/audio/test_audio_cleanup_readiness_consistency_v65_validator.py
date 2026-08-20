"""Focused tests for v65 readiness/consistency summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_readiness_consistency_v65_validator as validator  # noqa: E402


def summary() -> dict:
    readiness, consistency = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "readiness_digest": readiness, "consistency_digest": consistency, "readiness_id": "readiness-v65", "consistency_id": "consistency-v65", "canonicalization": "json-sorted-v1", "evidence": evidence, "readiness_pass": True}
    return {"schema": "audio_cleanup_readiness_consistency_v65", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-readiness-v65", "evidence_bundle": "artifacts/audio/readiness-v65.json", "canonicalization": "json-sorted-v1", "readiness_id": "readiness-v65", "consistency_id": "consistency-v65", "claim": "AUTOMATED_READINESS_CONSISTENCY_ONLY", "boundary_note": "Readiness consistency does not establish native audibility.", "record_ids": ["record-a", "record-b"], "readiness_digest": readiness, "consistency_digest": consistency, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "readiness_consistency_pass": True}


class AudioCleanupReadinessConsistencyV65Tests(unittest.TestCase):
    def test_valid_readiness_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_consistency_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["consistency_id"] = "other"
        self.assertIn("records[1].consistency_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["readiness_digest"] = "c" * 64
        self.assertIn("records readiness/consistency digest pairs must agree", validator.validate_summary(value))

    def test_readiness_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["readiness_consistency_pass"] = False
        value["records"][0]["readiness_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("readiness_consistency_pass must be true", errors)
        self.assertIn("records[0].readiness_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
