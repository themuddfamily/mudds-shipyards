"""Focused tests for v71 release/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_lineage_v71_validator as validator  # noqa: E402


def summary() -> dict:
    release, lineage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "release_digest": release, "lineage_digest": lineage, "release_id": "release-v71", "lineage_id": "lineage-v71", "canonicalization": "json-sorted-v1", "evidence": evidence, "lineage_pass": True}
    return {"schema": "audio_cleanup_release_lineage_v71", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-release-lineage-v71", "evidence_bundle": "artifacts/audio/release-lineage-v71.json", "canonicalization": "json-sorted-v1", "release_id": "release-v71", "lineage_id": "lineage-v71", "claim": "AUTOMATED_RELEASE_LINEAGE_ONLY", "boundary_note": "Release lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "release_digest": release, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "release_lineage_pass": True}


class AudioCleanupReleaseLineageV71Tests(unittest.TestCase):
    def test_valid_release_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["release_digest"] = "c" * 64
        self.assertIn("records release/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["release_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("release_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
