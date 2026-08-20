import unittest

from tools.package.source_hash_schema_manifest_digest_v35 import validate_v35


def manifest():
    digest = "a" * 64
    return {
        "schema_version": 35,
        "build_label": "manifest-v35-42",
        "source_commit": "b" * 40,
        "manifest_version": "manifest-35",
        "manifest_id": "manifest-id-42",
        "manifest_digest": digest,
        "manifest": {"status": "PASS", "evidence": "manifest record", "schema_version": 35, "manifest_version": "manifest-35", "manifest_id": "manifest-id-42", "digest": digest},
        "audit": {"status": "PASS", "evidence": "manifest audit", "manifest_version": "manifest-35", "manifest_id": "manifest-id-42", "digest_matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSchemaManifestDigestV35Test(unittest.TestCase):
    def test_accepts_schema_manifest_digest(self):
        self.assertEqual(validate_v35(manifest()), [])

    def test_requires_schema_v35_and_matching_manifest_version(self):
        item = manifest()
        item["schema_version"] = 34
        item["manifest"]["manifest_version"] = "other"
        errors = validate_v35(item)
        self.assertTrue(any("schema_version must be 35" in error for error in errors))
        self.assertTrue(any("manifest_version must match" in error for error in errors))

    def test_rejects_manifest_digest_or_id_drift(self):
        item = manifest()
        item["manifest"]["digest"] = "c" * 64
        item["audit"]["manifest_id"] = "other"
        errors = validate_v35(item)
        self.assertTrue(any("manifest.digest must match" in error for error in errors))
        self.assertTrue(any("manifest identity must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = manifest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v35(item)))


if __name__ == "__main__":
    unittest.main()
