"""Focused tests for v52 release/version linkage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_version_linkage_summary_v52_validator as validator  # noqa: E402


def summary() -> dict:
    linkage, release = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "linkage_digest": linkage, "release_digest": release, "release_id": "release-v52", "release_version": "r52", "linkage_id": "linkage-v52", "canonicalization": "json-sorted-v1", "evidence": evidence, "linkage_pass": True}
    return {"schema": "audio_cleanup_release_version_linkage_summary_v52", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-linkage-v52", "evidence_bundle": "artifacts/audio/linkage-v52.json", "canonicalization": "json-sorted-v1", "release_id": "release-v52", "release_version": "r52", "release_versions": ["r51", "r52"], "linkage_id": "linkage-v52", "claim": "AUTOMATED_RELEASE_VERSION_LINKAGE_ONLY", "boundary_note": "Linkage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "linkage_digest": linkage, "release_digest": release, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "release_linkage_pass": True}


class AudioCleanupReleaseVersionLinkageV52Tests(unittest.TestCase):
    def test_valid_linkage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_linkage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["linkage_id"] = "other"
        self.assertIn("records[1].linkage_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r51"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_linkage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["release_linkage_pass"] = False
        value["records"][0]["linkage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("release_linkage_pass must be true", errors)
        self.assertIn("records[0].linkage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
