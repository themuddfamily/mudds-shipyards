import unittest

from tools.package.source_hash_dual_version_authority_provenance_link_v45 import validate_v45


def linked():
    commit = "f" * 40
    source_version = "src-45"
    package_version = "4.5.0"
    return {
        "schema_version": 45,
        "build_label": "dual-link-v45",
        "source_commit": commit,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-45",
        "provenance_id": "provenance-45",
        "link_id": "link-45",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-45", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": "provenance-45", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "link": {"status": "PASS", "evidence": "link", "link_id": "link-45", "authority_id": "authority-45", "provenance_id": "provenance-45", "source_commit": commit, "source_version": source_version, "package_version": package_version, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDualVersionAuthorityProvenanceLinkV45Test(unittest.TestCase):
    def test_accepts_dual_version_link(self):
        self.assertEqual(validate_v45(linked()), [])

    def test_requires_link_versions(self):
        item = linked()
        item["link"]["source_version"] = "src-other"
        item["link"]["package_version"] = "4.4.0"
        errors = validate_v45(item)
        self.assertTrue(any("link.source_version must match" in error for error in errors))
        self.assertTrue(any("link.package_version must match" in error for error in errors))

    def test_rejects_unlinked_record_or_schema_drift(self):
        item = linked()
        item["schema_version"] = 44
        item["link"]["linked"] = False
        errors = validate_v45(item)
        self.assertTrue(any("schema_version must be 45" in error for error in errors))
        self.assertTrue(any("linked must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = linked()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v45(item)))


if __name__ == "__main__":
    unittest.main()
