import unittest

from tools.package.source_hash_linked_authority_provenance_version_v43 import validate_v43


def linked():
    commit = "b" * 40
    version = "4.3.0"
    return {
        "schema_version": 43,
        "build_label": "linked-v43",
        "source_commit": commit,
        "package_version": version,
        "authority_id": "authority-43",
        "provenance_id": "provenance-43",
        "link_id": "link-43",
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-43", "source_commit": commit, "package_version": version},
        "provenance": {"status": "PASS", "evidence": "provenance record", "provenance_id": "provenance-43", "source_commit": commit, "package_version": version},
        "link": {"status": "PASS", "evidence": "link report", "link_id": "link-43", "authority_id": "authority-43", "provenance_id": "provenance-43", "source_commit": commit, "package_version": version, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashLinkedAuthorityProvenanceVersionV43Test(unittest.TestCase):
    def test_accepts_linked_versioned_evidence(self):
        self.assertEqual(validate_v43(linked()), [])

    def test_rejects_schema_and_version_drift(self):
        item = linked()
        item["schema_version"] = 42
        item["authority"]["package_version"] = "4.2.0"
        errors = validate_v43(item)
        self.assertTrue(any("schema_version must be 43" in error for error in errors))
        self.assertTrue(any("authority.package_version must match" in error for error in errors))

    def test_requires_link_identity_and_source_binding(self):
        item = linked()
        item["link"]["link_id"] = "other"
        item["link"]["source_commit"] = "c" * 40
        errors = validate_v43(item)
        self.assertTrue(any("link.link_id must match" in error for error in errors))
        self.assertTrue(any("link.source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = linked()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v43(item)))


if __name__ == "__main__":
    unittest.main()
