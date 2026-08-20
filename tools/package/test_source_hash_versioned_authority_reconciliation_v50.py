import unittest

from tools.package.source_hash_versioned_authority_reconciliation_v50 import validate_v50


def record():
    commit = "5" * 40
    digest = "f" * 64
    source_version = "src-50"
    package_version = "5.0.0"
    channel = "stable"
    return {
        "schema_version": 50,
        "build_label": "authority-reconciliation-v50",
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "release_channel": channel,
        "authority_id": "authority-50",
        "authority": {"status": "PASS", "evidence": "authority", "authority_id": "authority-50", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "release_channel": channel, "authorized": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "authority_id": "authority-50", "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "release_channel": channel, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashVersionedAuthorityReconciliationV50Test(unittest.TestCase):
    def test_accepts_channel_bound_reconciliation(self):
        self.assertEqual(validate_v50(record()), [])

    def test_requires_channel_and_hash_alignment(self):
        item = record()
        item["reconciliation"]["release_channel"] = "beta"
        item["authority"]["source_hash"] = "a" * 64
        errors = validate_v50(item)
        self.assertTrue(any("reconciliation.release_channel must match" in error for error in errors))
        self.assertTrue(any("authority.source_hash must match" in error for error in errors))

    def test_rejects_schema_or_reconciled_drift(self):
        item = record()
        item["schema_version"] = 49
        item["reconciliation"]["reconciled"] = False
        errors = validate_v50(item)
        self.assertTrue(any("schema_version must be 50" in error for error in errors))
        self.assertTrue(any("reconciled must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v50(item)))


if __name__ == "__main__":
    unittest.main()
