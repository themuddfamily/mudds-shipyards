"""Focused tests for v38 linked authority/reconciliation digests."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_authority_reconciliation_linked_digest_summary_v38_validator as validator  # noqa: E402


def summary() -> dict:
    authority, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "reconciliation_digest": reconciliation, "authority_id": "authority-v38", "authority_record_id": "record-a", "reconciliation_record_id": "record-b", "canonicalization": "json-sorted-v1", "evidence": evidence, "link_pass": True}
    return {"schema": "audio_cleanup_authority_reconciliation_linked_digest_summary_v38", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-linked-v38", "evidence_bundle": "artifacts/audio/linked-v38.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v38", "authority_record_id": "record-a", "reconciliation_record_id": "record-b", "claim": "AUTOMATED_LINKED_AUTHORITY_RECONCILIATION_DIGEST_ONLY", "boundary_note": "Linked reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "linked_reconciliation_pass": True}


class AudioCleanupAuthorityReconciliationLinkedV38Tests(unittest.TestCase):
    def test_valid_linked_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_link_reference_is_required(self):
        value = copy.deepcopy(summary())
        value["reconciliation_record_id"] = "record-z"
        self.assertIn("reconciliation_record_id must reference a record", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "c" * 64
        self.assertIn("records linked digest pairs must agree", validator.validate_summary(value))

    def test_link_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["linked_reconciliation_pass"] = False
        value["records"][0]["link_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("linked_reconciliation_pass must be true", errors)
        self.assertIn("records[0].link_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
