"""Focused tests for v63 release/authority summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_release_authority_v63_validator as validator  # noqa: E402


def summary() -> dict:
    release, authority = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "release_digest": release, "authority_digest": authority, "release_id": "release-v63", "authority_id": "authority-v63", "canonicalization": "json-sorted-v1", "evidence": evidence, "authority_pass": True}
    return {"schema": "audio_cleanup_release_authority_v63", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-release-authority-v63", "evidence_bundle": "artifacts/audio/release-authority-v63.json", "canonicalization": "json-sorted-v1", "release_id": "release-v63", "authority_id": "authority-v63", "claim": "AUTOMATED_RELEASE_AUTHORITY_ONLY", "boundary_note": "Release authority does not establish native audibility.", "record_ids": ["record-a", "record-b"], "release_digest": release, "authority_digest": authority, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "release_authority_pass": True}


class AudioCleanupReleaseAuthorityV63Tests(unittest.TestCase):
    def test_valid_release_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_id"] = "other"
        self.assertIn("records[1].authority_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["release_digest"] = "c" * 64
        self.assertIn("records release/authority digest pairs must agree", validator.validate_summary(value))

    def test_authority_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["release_authority_pass"] = False
        value["records"][0]["authority_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("release_authority_pass must be true", errors)
        self.assertIn("records[0].authority_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
