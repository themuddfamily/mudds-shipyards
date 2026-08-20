import unittest

from tools.package.source_hash_versioned_authority_reconciliation_v49 import validate_v49


def record():
    commit = "4" * 40
    digest = "e" * 64
    source_version = "src-49"
    package_version = "4.9.0"
    return {
        "schema_version": 49,
        "build_label": "authority-reconciliation-v49",
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-49",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-49", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "authorized": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "authority_id": "authority-49", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVersionedAuthorityReconciliationV49Test(unittest.TestCase):
    def test_accepts_versioned_authority_reconciliation(self):
        self.assertEqual(validate_v49(record()), [])

    def test_requires_reconciliation_hash_and_version_binding(self):
        item = record()
        item["reconciliation"]["source_hash"] = "f" * 64
        item["reconciliation"]["package_version"] = "4.8.0"
        errors = validate_v49(item)
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))
        self.assertTrue(any("reconciliation.package_version must match" in error for error in errors))

    def test_rejects_schema_or_authority_drift(self):
        item = record()
        item["schema_version"] = 48
        item["authority"]["authorized"] = False
        errors = validate_v49(item)
        self.assertTrue(any("schema_version must be 49" in error for error in errors))
        self.assertTrue(any("authorized must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v49(item)))


if __name__ == "__main__":
    unittest.main()
