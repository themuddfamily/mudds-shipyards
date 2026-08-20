"""Focused tests for v53 release/version reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_version_reconciliation_summary_v53_validator as validator  # noqa: E402


def summary() -> dict:
    reconciliation, release = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "reconciliation_digest": reconciliation, "release_digest": release, "release_id": "release-v53", "release_version": "r53", "reconciliation_id": "reconciliation-v53", "canonicalization": "json-sorted-v1", "evidence": evidence, "reconciliation_pass": True}
    return {"schema": "audio_cleanup_release_version_reconciliation_summary_v53", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-reconciliation-v53", "evidence_bundle": "artifacts/audio/reconciliation-v53.json", "canonicalization": "json-sorted-v1", "release_id": "release-v53", "release_version": "r53", "release_versions": ["r52", "r53"], "reconciliation_id": "reconciliation-v53", "claim": "AUTOMATED_RELEASE_VERSION_RECONCILIATION_ONLY", "boundary_note": "Release reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "reconciliation_digest": reconciliation, "release_digest": release, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "release_reconciliation_pass": True}


class AudioCleanupReleaseVersionReconciliationV53Tests(unittest.TestCase):
    def test_valid_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_reconciliation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_id"] = "other"
        self.assertIn("records[1].reconciliation_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r52"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_reconciliation_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["release_reconciliation_pass"] = False
        value["records"][0]["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("release_reconciliation_pass must be true", errors)
        self.assertIn("records[0].reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
