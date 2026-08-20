import unittest

from tools.package.source_hash_release_version_linkage_v52 import validate_v52


def record():
    commit = "7" * 40
    digest = "b" * 64
    source_version = "src-52"
    package_version = "5.2.0"
    release_id = "release-52"
    link_id = "link-52"
    return {
        "schema_version": 52,
        "build_label": "release-linkage-v52",
        "release_id": release_id,
        "link_id": link_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "linkage": {"status": "PASS", "evidence": "linkage", "release_id": release_id, "link_id": link_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseVersionLinkageV52Test(unittest.TestCase):
    def test_accepts_release_version_linkage(self):
        self.assertEqual(validate_v52(record()), [])

    def test_requires_link_identity_and_version_binding(self):
        item = record()
        item["linkage"]["link_id"] = "link-other"
        item["linkage"]["source_version"] = "src-other"
        errors = validate_v52(item)
        self.assertTrue(any("linkage.link_id must match" in error for error in errors))
        self.assertTrue(any("linkage.source_version must match" in error for error in errors))

    def test_rejects_schema_or_unlinked_record(self):
        item = record()
        item["schema_version"] = 51
        item["linkage"]["linked"] = False
        errors = validate_v52(item)
        self.assertTrue(any("schema_version must be 52" in error for error in errors))
        self.assertTrue(any("linked must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v52(item)))


if __name__ == "__main__":
    unittest.main()
