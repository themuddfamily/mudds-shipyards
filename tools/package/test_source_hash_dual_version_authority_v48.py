import unittest

from tools.package.source_hash_dual_version_authority_v48 import validate_v48


def record():
    commit = "3" * 40
    digest = "d" * 64
    source_version = "src-48"
    package_version = "4.8.0"
    return {
        "schema_version": 48,
        "build_label": "authority-v48",
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-48",
        "authority": {"status": "PASS", "evidence": "signed authority", "authority_id": "authority-48", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "authorized": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDualVersionAuthorityV48Test(unittest.TestCase):
    def test_accepts_authorized_dual_version_record(self):
        self.assertEqual(validate_v48(record()), [])

    def test_requires_authority_hash_and_versions(self):
        item = record()
        item["authority"]["source_hash"] = "e" * 64
        item["authority"]["source_version"] = "src-other"
        errors = validate_v48(item)
        self.assertTrue(any("authority.source_hash must match" in error for error in errors))
        self.assertTrue(any("authority.source_version must match" in error for error in errors))

    def test_requires_authorized_flag_and_schema(self):
        item = record()
        item["schema_version"] = 47
        item["authority"]["authorized"] = False
        errors = validate_v48(item)
        self.assertTrue(any("schema_version must be 48" in error for error in errors))
        self.assertTrue(any("authorized must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "macOS"
        self.assertTrue(any("platform must be null" in error for error in validate_v48(item)))


if __name__ == "__main__":
    unittest.main()
