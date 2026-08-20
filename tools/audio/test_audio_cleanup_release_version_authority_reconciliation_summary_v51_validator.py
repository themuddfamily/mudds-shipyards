"""Focused tests for v51 release/version authority-reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_version_authority_reconciliation_summary_v51_validator as validator  # noqa: E402


def summary() -> dict:
    authority, reconciliation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "reconciliation_digest": reconciliation, "release_id": "release-v51", "authority_id": "authority-v51", "reconciliation_id": "reconciliation-v51", "release_version": "r51", "canonicalization": "json-sorted-v1", "evidence": evidence, "release_pass": True}
    return {"schema": "audio_cleanup_release_version_authority_reconciliation_summary_v51", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-release-v51", "evidence_bundle": "artifacts/audio/release-v51.json", "canonicalization": "json-sorted-v1", "release_id": "release-v51", "authority_id": "authority-v51", "reconciliation_id": "reconciliation-v51", "release_version": "r51", "release_versions": ["r50", "r51"], "claim": "AUTOMATED_RELEASE_VERSION_AUTHORITY_RECONCILIATION_ONLY", "boundary_note": "Release binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "release_reconciliation_pass": True}


class AudioCleanupReleaseVersionAuthorityReconciliationV51Tests(unittest.TestCase):
    def test_valid_release_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_release_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["release_id"] = "other"
        self.assertIn("records[1].release_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r50"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_release_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["release_reconciliation_pass"] = False
        value["records"][0]["release_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("release_reconciliation_pass must be true", errors)
        self.assertIn("records[0].release_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
