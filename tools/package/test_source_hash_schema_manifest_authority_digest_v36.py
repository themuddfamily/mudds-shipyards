import unittest

from tools.package.source_hash_schema_manifest_authority_digest_v36 import validate_v36


def authority():
    manifest_digest = "a" * 64
    authority_digest = "b" * 64
    return {
        "schema_version": 36,
        "build_label": "authority-v36-42",
        "source_commit": "c" * 40,
        "manifest_version": "manifest-36",
        "manifest_id": "manifest-id-42",
        "manifest_digest": manifest_digest,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "manifest": {"status": "PASS", "evidence": "manifest record", "manifest_version": "manifest-36", "manifest_id": "manifest-id-42", "digest": manifest_digest},
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "manifest_version": "manifest-36", "manifest_id": "manifest-id-42", "digest": authority_digest},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "manifest_id": "manifest-id-42", "authority_id": "authority-42", "authority_digest": authority_digest, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSchemaManifestAuthorityDigestV36Test(unittest.TestCase):
    def test_accepts_manifest_authority_digest(self):
        self.assertEqual(validate_v36(authority()), [])

    def test_requires_schema_v36_and_matching_authority_digest(self):
        item = authority()
        item["schema_version"] = 35
        item["authority"]["digest"] = "d" * 64
        errors = validate_v36(item)
        self.assertTrue(any("schema_version must be 36" in error for error in errors))
        self.assertTrue(any("authority.digest must match" in error for error in errors))

    def test_rejects_manifest_or_reconciliation_id_drift(self):
        item = authority()
        item["manifest"]["manifest_id"] = "other"
        item["reconciliation"]["authority_id"] = "other"
        errors = validate_v36(item)
        self.assertTrue(any("manifest identity must match" in error for error in errors))
        self.assertTrue(any("reconciliation IDs must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = authority()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v36(item)))


if __name__ == "__main__":
    unittest.main()
