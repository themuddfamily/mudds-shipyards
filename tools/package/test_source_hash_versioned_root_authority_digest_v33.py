import unittest

from tools.package.source_hash_versioned_root_authority_digest_v33 import validate_v33


def versioned():
    root_digest = "a" * 64
    authority_digest = "b" * 64
    return {
        "schema_version": 33,
        "build_label": "versioned-v33-42",
        "source_commit": "c" * 40,
        "record_version": "record-33",
        "root_id": "root-42",
        "root_digest": root_digest,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "root": {"status": "PASS", "evidence": "root record", "record_version": "record-33", "root_id": "root-42", "digest": root_digest},
        "authority": {"status": "PASS", "evidence": "authority record", "record_version": "record-33", "authority_id": "authority-42", "digest": authority_digest},
        "pair": {"status": "PASS", "evidence": "pair report", "record_version": "record-33", "root_id": "root-42", "authority_id": "authority-42", "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVersionedRootAuthorityDigestV33Test(unittest.TestCase):
    def test_accepts_versioned_root_authority(self):
        self.assertEqual(validate_v33(versioned()), [])

    def test_requires_schema_v33_and_record_version(self):
        item = versioned()
        item["schema_version"] = 32
        item["pair"]["record_version"] = "other"
        errors = validate_v33(item)
        self.assertTrue(any("schema_version must be 33" in error for error in errors))
        self.assertTrue(any("pair.record_version must match" in error for error in errors))

    def test_rejects_root_or_authority_identity_drift(self):
        item = versioned()
        item["root"]["digest"] = "d" * 64
        item["authority"]["authority_id"] = "other"
        errors = validate_v33(item)
        self.assertTrue(any("root identity must match" in error for error in errors))
        self.assertTrue(any("authority identity must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = versioned()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v33(item)))


if __name__ == "__main__":
    unittest.main()
