import unittest

from tools.package.source_hash_dual_version_reconciliation_v47 import validate_v47


def record():
    commit = "2" * 40
    digest = "a" * 64
    source_version = "src-47"
    package_version = "4.7.0"
    return {
        "schema_version": 47,
        "build_label": "reconciliation-v47",
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-47",
        "provenance_id": "provenance-47",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-47", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version},
        "provenance": {"status": "PASS", "evidence": "provenance", "provenance_id": "provenance-47", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "authority_id": "authority-47", "provenance_id": "provenance-47", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDualVersionReconciliationV47Test(unittest.TestCase):
    def test_accepts_source_hash_reconciliation(self):
        self.assertEqual(validate_v47(record()), [])

    def test_requires_reconciliation_hash_and_versions(self):
        item = record()
        item["reconciliation"]["source_hash"] = "b" * 64
        item["reconciliation"]["package_version"] = "4.6.0"
        errors = validate_v47(item)
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))
        self.assertTrue(any("reconciliation.package_version must match" in error for error in errors))

    def test_rejects_schema_or_authority_hash_drift(self):
        item = record()
        item["schema_version"] = 46
        item["authority"]["source_hash"] = "c" * 64
        errors = validate_v47(item)
        self.assertTrue(any("schema_version must be 47" in error for error in errors))
        self.assertTrue(any("authority.source_hash must match" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.json"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v47(item)))


if __name__ == "__main__":
    unittest.main()
