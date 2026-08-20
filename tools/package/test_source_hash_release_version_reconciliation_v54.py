import unittest

from tools.package.source_hash_release_version_reconciliation_v54 import validate_v54


def record():
    commit = "9" * 40
    digest = "d" * 64
    source_version = "src-54"
    package_version = "5.4.0"
    release_id = "release-54"
    channel = "stable"
    return {
        "schema_version": 54,
        "build_label": "release-reconciliation-v54",
        "release_id": release_id,
        "release_channel": channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "release_id": release_id, "release_channel": channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReleaseVersionReconciliationV54Test(unittest.TestCase):
    def test_accepts_channel_bound_reconciliation(self):
        self.assertEqual(validate_v54(record()), [])

    def test_requires_channel_and_hash_alignment(self):
        item = record()
        item["reconciliation"]["release_channel"] = "beta"
        item["reconciliation"]["source_hash"] = "e" * 64
        errors = validate_v54(item)
        self.assertTrue(any("reconciliation.release_channel must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_rejects_schema_or_reconciled_drift(self):
        item = record()
        item["schema_version"] = 53
        item["reconciliation"]["reconciled"] = False
        errors = validate_v54(item)
        self.assertTrue(any("schema_version must be 54" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v54(item)))


if __name__ == "__main__":
    unittest.main()
