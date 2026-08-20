"""Focused tests for v46 dual-version link/reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_dual_version_link_reconciliation_summary_v46_validator as validator  # noqa: E402


def summary() -> dict:
    link, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "link_digest": link, "reconciliation_digest": reconciliation, "authority_id": "authority-v46", "provenance_id": "provenance-v46", "link_id": "link-v46", "authority_version": "a46", "provenance_version": "p46", "canonicalization": "json-sorted-v1", "evidence": evidence, "reconciliation_pass": True}
    return {"schema": "audio_cleanup_dual_version_link_reconciliation_summary_v46", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-reconciliation-v46", "evidence_bundle": "artifacts/audio/reconciliation-v46.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v46", "provenance_id": "provenance-v46", "link_id": "link-v46", "authority_version": "a46", "provenance_version": "p46", "authority_versions": ["a45", "a46"], "provenance_versions": ["p45", "p46"], "claim": "AUTOMATED_DUAL_VERSION_LINK_RECONCILIATION_ONLY", "boundary_note": "Reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "link_digest": link, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "dual_reconciliation_pass": True}


class AudioCleanupDualVersionLinkReconciliationV46Tests(unittest.TestCase):
    def test_valid_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_reconciliation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "c" * 64
        self.assertIn("records[1].reconciliation_digest must match summary", validator.validate_summary(value))

    def test_dual_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["link_digest"] = "c" * 64
        self.assertIn("records dual-version link/reconciliation pairs must agree", validator.validate_summary(value))

    def test_reconciliation_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["dual_reconciliation_pass"] = False
        value["records"][0]["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("dual_reconciliation_pass must be true", errors)
        self.assertIn("records[0].reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
