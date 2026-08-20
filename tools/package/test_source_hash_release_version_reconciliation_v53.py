import unittest

from tools.package.source_hash_release_version_reconciliation_v53 import validate_v53


def record():
    commit = "8" * 40
    digest = "c" * 64
    source_version = "src-53"
    package_version = "5.3.0"
    release_id = "release-53"
    return {
        "schema_version": 53,
        "build_label": "release-reconciliation-v53",
        "release_id": release_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "release_id": release_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseVersionReconciliationV53Test(unittest.TestCase):
    def test_accepts_release_reconciliation(self):
        self.assertEqual(validate_v53(record()), [])

    def test_requires_release_hash_and_version_alignment(self):
        item = record()
        item["reconciliation"]["release_id"] = "release-other"
        item["reconciliation"]["source_hash"] = "d" * 64
        errors = validate_v53(item)
        self.assertTrue(any("reconciliation.release_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_rejects_schema_or_reconciled_drift(self):
        item = record()
        item["schema_version"] = 52
        item["reconciliation"]["reconciled"] = False
        errors = validate_v53(item)
        self.assertTrue(any("schema_version must be 53" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v53(item)))


if __name__ == "__main__":
    unittest.main()
