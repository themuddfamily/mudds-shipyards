"""Focused tests for v22 cleanup provenance reconciliation digest."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_reconciliation_digest_summary_v22_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["record-a", "record-b"]
    digest = "a" * 64
    records = [{"record_id": ids[0], "provenance_digest": digest, "canonicalization": "json-sorted-v1", "provenance_status": "project_original", "source": "project generator", "license": "project_original", "evidence": "artifacts/audio/prov-a.json", "reconciled": True}, {"record_id": ids[1], "provenance_digest": digest, "canonicalization": "json-sorted-v1", "provenance_status": "project_original", "source": "project generator", "license": "project_original", "evidence": "artifacts/audio/prov-b.json", "reconciled": True}]
    return {"schema": "audio_cleanup_provenance_reconciliation_digest_summary_v22", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-prov-v22", "evidence_bundle": "artifacts/audio/prov-v22.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_PROVENANCE_RECONCILIATION_ONLY", "boundary_note": "Provenance reconciliation does not establish native audibility.", "record_ids": ids, "provenance_digest": digest, "records": records, "provenance_pass": True}


class AudioCleanupProvenanceV22Tests(unittest.TestCase):
    def test_valid_provenance_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_provenance_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "b" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records provenance_digest values must agree", errors)

    def test_source_license_and_status_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["source"] = ""
        value["records"][1]["provenance_status"] = "unknown"
        errors = validator.validate_summary(value)
        self.assertIn("records[0].source is required", errors)
        self.assertIn("records[1].provenance_status is invalid", errors)

    def test_record_roster_and_reconciled_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["record_id"] = "record-c"
        value["records"][0]["reconciled"] = False
        errors = validator.validate_summary(value)
        self.assertIn("records[1].record_id must be in record_ids", errors)
        self.assertIn("records[0].reconciled must be true", errors)


if __name__ == "__main__":
    unittest.main()
