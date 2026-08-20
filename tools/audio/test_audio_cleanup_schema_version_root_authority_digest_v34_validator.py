"""Focused tests for v34 schema-versioned root/authority digests."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_schema_version_root_authority_digest_v34_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c, d = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "summary_digest": a, "reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "root_id": "record-a", "authority_id": "authority-v34", "schema_version": "v34", "canonicalization": "json-sorted-v1", "evidence": evidence, "schema_pass": True}
    return {"schema": "audio_cleanup_schema_version_root_authority_digest_v34", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-schema-v34", "evidence_bundle": "artifacts/audio/schema-v34.json", "canonicalization": "json-sorted-v1", "root_id": "record-a", "authority_id": "authority-v34", "schema_version": "v34", "schema_versions": ["v33", "v34"], "claim": "AUTOMATED_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_ONLY", "boundary_note": "Schema binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "root_summary_digest": a, "root_reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "schema_digest_pass": True}


class AudioCleanupSchemaVersionRootAuthorityDigestV34Tests(unittest.TestCase):
    def test_valid_schema_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_schema_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["schema_version"] = "v33"
        self.assertIn("records[1].schema_version must match summary", validator.validate_summary(value))

    def test_schema_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["schema_versions"] = ["v33"]
        self.assertIn("schema_version must be in schema_versions", validator.validate_summary(value))

    def test_schema_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["schema_digest_pass"] = False
        value["records"][0]["schema_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("schema_digest_pass must be true", errors)
        self.assertIn("records[0].schema_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
