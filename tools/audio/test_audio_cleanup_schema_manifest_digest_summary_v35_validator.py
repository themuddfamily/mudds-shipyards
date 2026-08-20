"""Focused tests for v35 schema/manifest digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_schema_manifest_digest_summary_v35_validator as validator  # noqa: E402


def summary() -> dict:
    manifest, schema = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "manifest_digest": manifest, "schema_digest": schema, "manifest_id": "manifest-v35", "schema_version": "v35", "canonicalization": "json-sorted-v1", "evidence": evidence, "manifest_pass": True}
    return {"schema": "audio_cleanup_schema_manifest_digest_summary_v35", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-manifest-v35", "evidence_bundle": "artifacts/audio/manifest-v35.json", "canonicalization": "json-sorted-v1", "manifest_id": "manifest-v35", "schema_version": "v35", "claim": "AUTOMATED_SCHEMA_MANIFEST_DIGEST_ONLY", "boundary_note": "Manifest binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "manifest_digest": manifest, "schema_digest": schema, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "manifest_digest_pass": True}


class AudioCleanupSchemaManifestDigestV35Tests(unittest.TestCase):
    def test_valid_manifest_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_manifest_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["manifest_id"] = "other"
        self.assertIn("records[1].manifest_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["schema_digest"] = "c" * 64
        self.assertIn("records manifest/schema digest pairs must agree", validator.validate_summary(value))

    def test_manifest_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["manifest_digest_pass"] = False
        value["records"][0]["manifest_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("manifest_digest_pass must be true", errors)
        self.assertIn("records[0].manifest_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
