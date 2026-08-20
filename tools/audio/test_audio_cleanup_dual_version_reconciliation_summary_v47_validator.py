"""Focused tests for v47 dual-version reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_dual_version_reconciliation_summary_v47_validator as validator  # noqa: E402


def summary() -> dict:
    reconciliation, authority = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "reconciliation_digest": reconciliation, "authority_digest": authority, "authority_id": "authority-v47", "provenance_id": "provenance-v47", "authority_version": "a47", "provenance_version": "p47", "canonicalization": "json-sorted-v1", "evidence": evidence, "reconciliation_pass": True}
    return {"schema": "audio_cleanup_dual_version_reconciliation_summary_v47", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-reconciliation-v47", "evidence_bundle": "artifacts/audio/reconciliation-v47.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v47", "provenance_id": "provenance-v47", "authority_version": "a47", "provenance_version": "p47", "authority_versions": ["a46", "a47"], "provenance_versions": ["p46", "p47"], "claim": "AUTOMATED_DUAL_VERSION_RECONCILIATION_ONLY", "boundary_note": "Reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "reconciliation_digest": reconciliation, "authority_digest": authority, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "dual_reconciliation_pass": True}


class AudioCleanupDualVersionReconciliationV47Tests(unittest.TestCase):
    def test_valid_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_reconciliation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "c" * 64
        self.assertIn("records[1].reconciliation_digest must match summary", validator.validate_summary(value))

    def test_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["authority_versions"] = ["a46"]
        self.assertIn("authority_version must be in authority_versions", validator.validate_summary(value))

    def test_reconciliation_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["dual_reconciliation_pass"] = False
        value["records"][0]["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("dual_reconciliation_pass must be true", errors)
        self.assertIn("records[0].reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
