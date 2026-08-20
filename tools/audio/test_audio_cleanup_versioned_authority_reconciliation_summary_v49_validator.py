"""Focused tests for v49 versioned authority/reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_versioned_authority_reconciliation_summary_v49_validator as validator  # noqa: E402


def summary() -> dict:
    authority, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "reconciliation_digest": reconciliation, "authority_id": "authority-v49", "reconciliation_id": "reconciliation-v49", "authority_version": "a49", "reconciliation_version": "r49", "canonicalization": "json-sorted-v1", "evidence": evidence, "version_pass": True}
    return {"schema": "audio_cleanup_versioned_authority_reconciliation_summary_v49", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-versioned-reconciliation-v49", "evidence_bundle": "artifacts/audio/reconciliation-v49.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v49", "reconciliation_id": "reconciliation-v49", "authority_version": "a49", "reconciliation_version": "r49", "authority_versions": ["a48", "a49"], "reconciliation_versions": ["r48", "r49"], "claim": "AUTOMATED_VERSIONED_AUTHORITY_RECONCILIATION_ONLY", "boundary_note": "Versioned reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "versioned_reconciliation_pass": True}


class AudioCleanupVersionedAuthorityReconciliationV49Tests(unittest.TestCase):
    def test_valid_versioned_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_version"] = "r48"
        self.assertIn("records[1].reconciliation_version must match summary", validator.validate_summary(value))

    def test_reconciliation_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["reconciliation_versions"] = ["r48"]
        self.assertIn("reconciliation_version must be in reconciliation_versions", validator.validate_summary(value))

    def test_version_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["versioned_reconciliation_pass"] = False
        value["records"][0]["version_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("versioned_reconciliation_pass must be true", errors)
        self.assertIn("records[0].version_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
