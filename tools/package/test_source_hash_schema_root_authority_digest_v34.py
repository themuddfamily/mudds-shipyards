import unittest

from tools.package.source_hash_schema_root_authority_digest_v34 import validate_v34


def schema():
    root_digest = "a" * 64
    authority_digest = "b" * 64
    return {
        "schema_version": 34,
        "build_label": "schema-v34-42",
        "source_commit": "c" * 40,
        "record_version": "record-34",
        "root_id": "root-42",
        "root_digest": root_digest,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "root": {"status": "PASS", "evidence": "root record", "schema_version": 34, "record_version": "record-34", "root_id": "root-42", "digest": root_digest},
        "authority": {"status": "PASS", "evidence": "authority record", "schema_version": 34, "record_version": "record-34", "authority_id": "authority-42", "digest": authority_digest},
        "pair": {"status": "PASS", "evidence": "pair report", "schema_version": 34, "root_id": "root-42", "authority_id": "authority-42", "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSchemaRootAuthorityDigestV34Test(unittest.TestCase):
    def test_accepts_schema_root_authority(self):
        self.assertEqual(validate_v34(schema()), [])

    def test_requires_schema_v34_and_matching_versions(self):
        item = schema()
        item["schema_version"] = 33
        item["authority"]["record_version"] = "other"
        errors = validate_v34(item)
        self.assertTrue(any("schema_version must be 34" in error for error in errors))
        self.assertTrue(any("authority schema/version must match" in error for error in errors))

    def test_rejects_root_or_pair_identity_drift(self):
        item = schema()
        item["root"]["root_id"] = "other"
        item["pair"]["authority_id"] = "other"
        errors = validate_v34(item)
        self.assertTrue(any("root identity must match" in error for error in errors))
        self.assertTrue(any("pair IDs must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = schema()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v34(item)))


if __name__ == "__main__":
    unittest.main()
