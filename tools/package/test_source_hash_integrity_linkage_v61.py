import unittest

from tools.package.source_hash_integrity_linkage_v61 import validate_v61


def record():
    commit = "1" * 40
    digest = "e" * 64
    source_id = "source-61"
    source_version = "src-61"
    package_version = "6.1.0"
    link_id = "link-61"
    return {
        "schema_version": 61,
        "build_label": "integrity-linkage-v61",
        "source_id": source_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "link_id": link_id,
        "integrity": {"status": "PASS", "evidence": "integrity", "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "verified": True},
        "linkage": {"status": "PASS", "evidence": "linkage", "link_id": link_id, "source_id": source_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashIntegrityLinkageV61Test(unittest.TestCase):
    def test_accepts_verified_linkage(self):
        self.assertEqual(validate_v61(record()), [])

    def test_requires_integrity_and_link_hash_binding(self):
        item = record()
        item["integrity"]["source_hash"] = "f" * 64
        item["linkage"]["source_version"] = "src-other"
        errors = validate_v61(item)
        self.assertTrue(any("integrity.source_hash must match" in error for error in errors))
        self.assertTrue(any("linkage.source_version must match" in error for error in errors))

    def test_rejects_schema_or_integrity_flags(self):
        item = record()
        item["schema_version"] = 60
        item["integrity"]["verified"] = False
        item["linkage"]["linked"] = False
        errors = validate_v61(item)
        self.assertTrue(any("schema_version must be 61" in error for error in errors))
        self.assertTrue(any("verified must be true" in error for error in errors))
        self.assertTrue(any("linked must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v61(item)))


if __name__ == "__main__":
    unittest.main()
