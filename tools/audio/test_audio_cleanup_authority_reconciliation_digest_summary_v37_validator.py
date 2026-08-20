"""Focused tests for v37 authority/reconciliation digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_authority_reconciliation_digest_summary_v37_validator as validator  # noqa: E402


def summary() -> dict:
    authority, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "reconciliation_digest": reconciliation, "authority_id": "authority-v37", "canonicalization": "json-sorted-v1", "evidence": evidence, "reconciliation_pass": True}
    return {"schema": "audio_cleanup_authority_reconciliation_digest_summary_v37", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-reconciliation-v37", "evidence_bundle": "artifacts/audio/reconciliation-v37.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v37", "claim": "AUTOMATED_AUTHORITY_RECONCILIATION_DIGEST_ONLY", "boundary_note": "Reconciliation binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "authority_reconciliation_pass": True}


class AudioCleanupAuthorityReconciliationDigestV37Tests(unittest.TestCase):
    def test_valid_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_reconciliation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "c" * 64
        self.assertIn("records[1].reconciliation_digest must match summary", validator.validate_summary(value))

    def test_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "c" * 64
        self.assertIn("records authority/reconciliation digest pairs must agree", validator.validate_summary(value))

    def test_reconciliation_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["authority_reconciliation_pass"] = False
        value["records"][0]["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("authority_reconciliation_pass must be true", errors)
        self.assertIn("records[0].reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
