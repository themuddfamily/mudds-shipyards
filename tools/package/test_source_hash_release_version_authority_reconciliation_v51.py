import unittest

from tools.package.source_hash_release_version_authority_reconciliation_v51 import validate_v51


def record():
    commit = "6" * 40
    digest = "a" * 64
    source_version = "src-51"
    package_version = "5.1.0"
    release_id = "release-51"
    return {
        "schema_version": 51,
        "build_label": "release-reconciliation-v51",
        "release_id": release_id,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "authority_id": "authority-51",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-51", "release_id": release_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "authorized": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "authority_id": "authority-51", "release_id": release_id, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseVersionAuthorityReconciliationV51Test(unittest.TestCase):
    def test_accepts_release_bound_reconciliation(self):
        self.assertEqual(validate_v51(record()), [])

    def test_requires_release_and_version_alignment(self):
        item = record()
        item["reconciliation"]["release_id"] = "release-other"
        item["authority"]["package_version"] = "5.0.0"
        errors = validate_v51(item)
        self.assertTrue(any("reconciliation.release_id must match" in error for error in errors))
        self.assertTrue(any("authority.package_version must match" in error for error in errors))

    def test_rejects_schema_or_reconciled_drift(self):
        item = record()
        item["schema_version"] = 50
        item["reconciliation"]["reconciled"] = False
        errors = validate_v51(item)
        self.assertTrue(any("schema_version must be 51" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.txt"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v51(item)))


if __name__ == "__main__":
    unittest.main()
