"""Focused tests for v36 schema/manifest/authority digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_schema_manifest_authority_digest_summary_v36_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "manifest_digest": a, "schema_digest": b, "authority_digest": c, "manifest_id": "manifest-v36", "authority_id": "authority-v36", "schema_version": "v36", "canonicalization": "json-sorted-v1", "evidence": evidence, "authority_pass": True}
    return {"schema": "audio_cleanup_schema_manifest_authority_digest_summary_v36", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-authority-v36", "evidence_bundle": "artifacts/audio/authority-v36.json", "canonicalization": "json-sorted-v1", "manifest_id": "manifest-v36", "authority_id": "authority-v36", "schema_version": "v36", "claim": "AUTOMATED_SCHEMA_MANIFEST_AUTHORITY_DIGEST_ONLY", "boundary_note": "Authority binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "manifest_digest": a, "schema_digest": b, "authority_digest": c, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "authority_digest_pass": True}


class AudioCleanupSchemaManifestAuthorityDigestV36Tests(unittest.TestCase):
    def test_valid_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_id"] = "other"
        self.assertIn("records[1].authority_id must match summary", validator.validate_summary(value))

    def test_digest_triple_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "d" * 64
        self.assertIn("records manifest/schema/authority digest triples must agree", validator.validate_summary(value))

    def test_authority_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["authority_digest_pass"] = False
        value["records"][0]["authority_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("authority_digest_pass must be true", errors)
        self.assertIn("records[0].authority_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
