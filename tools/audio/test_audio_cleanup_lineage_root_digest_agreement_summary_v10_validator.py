"""Focused tests for v10 cleanup-lineage root digest agreement."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_lineage_root_digest_agreement_summary_v10_validator as validator  # noqa: E402


def summary() -> dict:
    root = "a" * 64
    records = [{"record_id": "record-1", "root_digest": root, "canonicalization": "json-sorted-v1", "root_evidence": "artifacts/audio/root-1.json", "root_verified": True}, {"record_id": "record-2", "root_digest": root, "canonicalization": "json-sorted-v1", "root_evidence": "artifacts/audio/root-2.json", "root_verified": True}]
    return {"schema": "audio_cleanup_lineage_root_digest_agreement_summary_v10", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-root-v10", "evidence_bundle": "artifacts/audio/root-v10.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_ROOT_AGREEMENT_ONLY", "boundary_note": "Root agreement does not establish native audibility.", "agreed_root_digest": root, "agreement_pass": True, "records": records}


class AudioCleanupRootAgreementV10Tests(unittest.TestCase):
    def test_valid_root_agreement(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_cross_record_root_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["root_digest"] = "b" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records root_digest values must agree", errors)

    def test_root_verification_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["root_verified"] = False
        value["records"][1]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[0].root_verified must be true", errors)
        self.assertIn("records[1].canonicalization must match summary canonicalization", errors)

    def test_agreement_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["agreement_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("agreement_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
