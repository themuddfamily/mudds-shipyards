"""Focused tests for v23 cleanup provenance identity reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_identity_reconciliation_summary_v23_validator as validator  # noqa: E402


def summary() -> dict:
    canonical = "json-sorted-v1"
    identities = [{"identity_id": "identity-a", "asset_id": "asset-a", "source_id": "source-a", "source": "project generator", "license": "project_original", "status": "project_original", "digest": "a" * 64, "canonicalization": canonical, "evidence": "artifacts/audio/a.json", "reconciled": True}, {"identity_id": "identity-b", "asset_id": "asset-b", "source_id": "source-b", "source": "project generator", "license": "project_original", "status": "project_original", "digest": "b" * 64, "canonicalization": canonical, "evidence": "artifacts/audio/b.json", "reconciled": True}]
    ids = [item["identity_id"] for item in identities]
    records = [{"record_id": "record-1", "identity_ids": ids, "provenance_digest": "c" * 64, "canonicalization": canonical, "evidence": "artifacts/audio/rec-1.json", "identity_pass": True}, {"record_id": "record-2", "identity_ids": ids, "provenance_digest": "c" * 64, "canonicalization": canonical, "evidence": "artifacts/audio/rec-2.json", "identity_pass": True}]
    return {"schema": "audio_cleanup_provenance_identity_reconciliation_summary_v23", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-identity-v23", "evidence_bundle": "artifacts/audio/identity-v23.json", "canonicalization": canonical, "claim": "AUTOMATED_PROVENANCE_IDENTITY_ONLY", "boundary_note": "Identity reconciliation does not establish native audibility.", "identities": identities, "records": records, "identity_reconciliation_pass": True}


class AudioCleanupProvenanceIdentityV23Tests(unittest.TestCase):
    def test_valid_identity_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_record_identity_roster_must_match(self):
        value = copy.deepcopy(summary())
        value["records"][1]["identity_ids"] = ["identity-a"]
        errors = validator.validate_summary(value)
        self.assertIn("records[1].identity_ids must match identities", errors)

    def test_provenance_status_and_source_are_required(self):
        value = copy.deepcopy(summary())
        value["identities"][0]["status"] = "unknown"
        value["identities"][1]["source"] = ""
        errors = validator.validate_summary(value)
        self.assertIn("identities[0].status is invalid", errors)
        self.assertIn("identities[1].source is required", errors)

    def test_record_digest_and_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "bad"
        value["records"][0]["identity_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("records[1].provenance_digest must be a lowercase 64-character digest", errors)
        self.assertIn("records[0].identity_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
