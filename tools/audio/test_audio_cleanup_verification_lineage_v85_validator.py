"""Focused tests for v85 verification/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_verification_lineage_v85_validator as validator  # noqa: E402


def summary() -> dict:
    verification, lineage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "verification_digest": verification, "lineage_digest": lineage, "verification_id": "verification-v85", "lineage_id": "lineage-v85", "canonicalization": "json-sorted-v1", "evidence": evidence, "lineage_pass": True}
    return {"schema": "audio_cleanup_verification_lineage_v85", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-verification-lineage-v85", "evidence_bundle": "artifacts/audio/verification-lineage-v85.json", "canonicalization": "json-sorted-v1", "verification_id": "verification-v85", "lineage_id": "lineage-v85", "claim": "AUTOMATED_VERIFICATION_LINEAGE_ONLY", "boundary_note": "Verification lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "verification_digest": verification, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "verification_lineage_pass": True}


class AudioCleanupVerificationLineageV85Tests(unittest.TestCase):
    def test_valid_verification_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["verification_digest"] = "c" * 64
        self.assertIn("records verification/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["verification_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("verification_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
