import unittest

from tools.package.source_hash_dual_version_authority_provenance_v44 import validate_v44


def linked():
    commit = "e" * 40
    source_version = "src-44"
    package_version = "4.4.0"
    return {
        "schema_version": 44,
        "build_label": "dual-v44",
        "source_commit": commit,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-44",
        "provenance_id": "provenance-44",
        "link_id": "link-44",
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-44", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "provenance": {"status": "PASS", "evidence": "provenance record", "provenance_id": "provenance-44", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "link": {"status": "PASS", "evidence": "link report", "link_id": "link-44", "authority_id": "authority-44", "provenance_id": "provenance-44", "source_commit": commit, "source_version": source_version, "package_version": package_version, "linked": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDualVersionAuthorityProvenanceV44Test(unittest.TestCase):
    def test_accepts_dual_version_linked_evidence(self):
        self.assertEqual(validate_v44(linked()), [])

    def test_requires_both_versions_to_match(self):
        item = linked()
        item["provenance"]["source_version"] = "src-other"
        item["link"]["package_version"] = "4.3.0"
        errors = validate_v44(item)
        self.assertTrue(any("provenance.source_version must match" in error for error in errors))
        self.assertTrue(any("link.package_version must match" in error for error in errors))

    def test_rejects_schema_or_identity_drift(self):
        item = linked()
        item["schema_version"] = 43
        item["authority"]["authority_id"] = "other"
        errors = validate_v44(item)
        self.assertTrue(any("schema_version must be 44" in error for error in errors))
        self.assertTrue(any("authority.authority_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = linked()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v44(item)))


if __name__ == "__main__":
    unittest.main()
