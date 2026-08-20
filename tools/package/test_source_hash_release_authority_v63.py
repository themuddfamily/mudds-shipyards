import unittest

from tools.package.source_hash_release_authority_v63 import validate_v63


def record():
    commit = "3" * 40
    digest = "a" * 64
    release_id = "release-63"
    authority_id = "authority-63"
    source_version = "src-63"
    package_version = "6.3.0"
    return {
        "schema_version": 63,
        "build_label": "release-authority-v63",
        "release_id": release_id,
        "authority_id": authority_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "authority": {"status": "PASS", "evidence": "authority", "release_id": release_id, "authority_id": authority_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "authorized": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseAuthorityV63Test(unittest.TestCase):
    def test_accepts_authorized_release(self):
        self.assertEqual(validate_v63(record()), [])

    def test_requires_release_and_authority_hash_binding(self):
        item = record()
        item["authority"]["release_id"] = "release-other"
        item["authority"]["source_hash"] = "b" * 64
        errors = validate_v63(item)
        self.assertTrue(any("authority.release_id must match" in error for error in errors))
        self.assertTrue(any("authority.source_hash must match" in error for error in errors))

    def test_rejects_schema_or_authorization_drift(self):
        item = record()
        item["schema_version"] = 62
        item["authority"]["authorized"] = False
        errors = validate_v63(item)
        self.assertTrue(any("schema_version must be 63" in error for error in errors))
        self.assertTrue(any("authorized must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v63(item)))


if __name__ == "__main__":
    unittest.main()
