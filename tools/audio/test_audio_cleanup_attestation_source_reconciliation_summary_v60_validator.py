"""Focused tests for v60 attestation/source reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_attestation_source_reconciliation_summary_v60_validator as validator  # noqa: E402


def summary() -> dict:
    attestation, source, reconciliation = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "attestation_digest": attestation, "source_digest": source, "reconciliation_digest": reconciliation, "attestation_id": "attestation-v60", "source_id": "source-v60", "reconciliation_id": "reconciliation-v60", "canonicalization": "json-sorted-v1", "evidence": evidence, "attestation_pass": True}
    return {"schema": "audio_cleanup_attestation_source_reconciliation_summary_v60", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-attestation-v60", "evidence_bundle": "artifacts/audio/attestation-v60.json", "canonicalization": "json-sorted-v1", "attestation_id": "attestation-v60", "source_id": "source-v60", "reconciliation_id": "reconciliation-v60", "claim": "AUTOMATED_ATTESTATION_SOURCE_RECONCILIATION_ONLY", "boundary_note": "Attestation reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "attestation_digest": attestation, "source_digest": source, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "attestation_reconciliation_pass": True}


class AudioCleanupAttestationSourceReconciliationV60Tests(unittest.TestCase):
    def test_valid_attestation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_attestation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["attestation_id"] = "other"
        self.assertIn("records[1].attestation_id must match summary", validator.validate_summary(value))

    def test_triple_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_digest"] = "d" * 64
        self.assertIn("records attestation/source/reconciliation triples must agree", validator.validate_summary(value))

    def test_attestation_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["attestation_reconciliation_pass"] = False
        value["records"][0]["attestation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("attestation_reconciliation_pass must be true", errors)
        self.assertIn("records[0].attestation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
