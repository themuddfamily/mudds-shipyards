"""Focused tests for v33 versioned root/authority digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_versioned_root_authority_digest_summary_v33_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c, d = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "summary_digest": a, "reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "root_id": "record-a", "authority_id": "authority-v33", "authority_version": "v33", "canonicalization": "json-sorted-v1", "evidence": evidence, "version_pass": True}
    return {"schema": "audio_cleanup_versioned_root_authority_digest_summary_v33", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-versioned-v33", "evidence_bundle": "artifacts/audio/versioned-v33.json", "canonicalization": "json-sorted-v1", "root_id": "record-a", "authority_id": "authority-v33", "authority_version": "v33", "supported_versions": ["v32", "v33"], "claim": "AUTOMATED_VERSIONED_ROOT_AUTHORITY_DIGEST_ONLY", "boundary_note": "Version binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "root_summary_digest": a, "root_reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "versioned_digest_pass": True}


class AudioCleanupVersionedRootAuthorityDigestV33Tests(unittest.TestCase):
    def test_valid_versioned_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_version"] = "v32"
        self.assertIn("records[1].authority_version must match summary", validator.validate_summary(value))

    def test_supported_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["supported_versions"] = ["v32"]
        self.assertIn("authority_version must be in supported_versions", validator.validate_summary(value))

    def test_versioned_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["versioned_digest_pass"] = False
        value["records"][0]["version_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("versioned_digest_pass must be true", errors)
        self.assertIn("records[0].version_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
