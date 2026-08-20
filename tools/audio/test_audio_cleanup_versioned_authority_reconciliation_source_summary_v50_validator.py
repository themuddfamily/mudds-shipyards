"""Focused tests for v50 source-bound versioned reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_versioned_authority_reconciliation_source_summary_v50_validator as validator  # noqa: E402


def summary() -> dict:
    authority, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "reconciliation_digest": reconciliation, "authority_id": "authority-v50", "reconciliation_id": "reconciliation-v50", "reconciliation_source": "source-v50", "authority_version": "a50", "reconciliation_version": "r50", "canonicalization": "json-sorted-v1", "evidence": evidence, "source_pass": True}
    return {"schema": "audio_cleanup_versioned_authority_reconciliation_source_summary_v50", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-v50", "evidence_bundle": "artifacts/audio/source-v50.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v50", "reconciliation_id": "reconciliation-v50", "reconciliation_source": "source-v50", "authority_version": "a50", "reconciliation_version": "r50", "authority_versions": ["a49", "a50"], "reconciliation_versions": ["r49", "r50"], "claim": "AUTOMATED_VERSIONED_AUTHORITY_RECONCILIATION_SOURCE_ONLY", "boundary_note": "Source binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_reconciliation_pass": True}


class AudioCleanupVersionedAuthorityReconciliationSourceV50Tests(unittest.TestCase):
    def test_valid_source_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_source_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_source"] = "other"
        self.assertIn("records[1].reconciliation_source must match summary", validator.validate_summary(value))

    def test_source_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "c" * 64
        self.assertIn("records source-bound authority/reconciliation pairs must agree", validator.validate_summary(value))

    def test_source_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_reconciliation_pass"] = False
        value["records"][0]["source_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_reconciliation_pass must be true", errors)
        self.assertIn("records[0].source_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
