import unittest

from tools.package.source_hash_dual_version_link_reconciliation_v46 import validate_v46


def linked():
    commit = "1" * 40
    source_version = "src-46"
    package_version = "4.6.0"
    return {
        "schema_version": 46,
        "build_label": "reconciliation-v46",
        "source_commit": commit,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-46",
        "provenance_id": "provenance-46",
        "link_id": "link-46",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-46", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": "provenance-46", "source_commit": commit, "source_version": source_version, "package_version": package_version},
        "link": {"status": "PASS", "evidence": "link", "link_id": "link-46", "authority_id": "authority-46", "provenance_id": "provenance-46", "source_commit": commit, "source_version": source_version, "package_version": package_version, "linked": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "link_id": "link-46", "authority_id": "authority-46", "provenance_id": "provenance-46", "source_commit": commit, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDualVersionLinkReconciliationV46Test(unittest.TestCase):
    def test_accepts_reconciled_link(self):
        self.assertEqual(validate_v46(linked()), [])

    def test_requires_reconciliation_identity_and_versions(self):
        item = linked()
        item["reconciliation"]["provenance_id"] = "other"
        item["reconciliation"]["source_version"] = "src-other"
        errors = validate_v46(item)
        self.assertTrue(any("reconciliation.provenance_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_version must match" in error for error in errors))

    def test_requires_reconciled_flag_and_schema(self):
        item = linked()
        item["schema_version"] = 45
        item["reconciliation"]["reconciled"] = False
        errors = validate_v46(item)
        self.assertTrue(any("schema_version must be 46" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = linked()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v46(item)))


if __name__ == "__main__":
    unittest.main()
