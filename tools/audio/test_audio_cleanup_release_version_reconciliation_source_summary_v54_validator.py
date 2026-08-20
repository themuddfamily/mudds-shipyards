"""Focused tests for v54 source-bound release reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_version_reconciliation_source_summary_v54_validator as validator  # noqa: E402


def summary() -> dict:
    reconciliation, release = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "reconciliation_digest": reconciliation, "release_digest": release, "release_id": "release-v54", "release_version": "r54", "reconciliation_id": "reconciliation-v54", "reconciliation_source": "source-v54", "canonicalization": "json-sorted-v1", "evidence": evidence, "source_pass": True}
    return {"schema": "audio_cleanup_release_version_reconciliation_source_summary_v54", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-v54", "evidence_bundle": "artifacts/audio/source-v54.json", "canonicalization": "json-sorted-v1", "release_id": "release-v54", "release_version": "r54", "release_versions": ["r53", "r54"], "reconciliation_id": "reconciliation-v54", "reconciliation_source": "source-v54", "claim": "AUTOMATED_RELEASE_VERSION_RECONCILIATION_SOURCE_ONLY", "boundary_note": "Source binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "reconciliation_digest": reconciliation, "release_digest": release, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_reconciliation_pass": True}


class AudioCleanupReleaseVersionReconciliationSourceV54Tests(unittest.TestCase):
    def test_valid_source_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_source_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_source"] = "other"
        self.assertIn("records[1].reconciliation_source must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r53"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_source_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_reconciliation_pass"] = False
        value["records"][0]["source_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_reconciliation_pass must be true", errors)
        self.assertIn("records[0].source_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
