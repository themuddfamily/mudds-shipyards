import unittest

from tools.package.source_hash_channel_release_reconciliation_v56 import validate_v56


def record():
    commit = "b" * 40
    digest = "f" * 64
    source_version = "src-56"
    package_version = "5.6.0"
    channel_id = "channel-56"
    release_id = "release-56"
    channel = "stable"
    return {
        "schema_version": 56,
        "build_label": "channel-reconciliation-v56",
        "channel_id": channel_id,
        "release_id": release_id,
        "release_channel": channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "channel_id": channel_id, "release_id": release_id, "release_channel": channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashChannelReleaseReconciliationV56Test(unittest.TestCase):
    def test_accepts_channel_release_reconciliation(self):
        self.assertEqual(validate_v56(record()), [])

    def test_requires_release_channel_and_version_binding(self):
        item = record()
        item["reconciliation"]["release_channel"] = "beta"
        item["reconciliation"]["package_version"] = "5.5.0"
        errors = validate_v56(item)
        self.assertTrue(any("reconciliation.release_channel must match" in error for error in errors))
        self.assertTrue(any("reconciliation.package_version must match" in error for error in errors))

    def test_rejects_schema_or_source_hash_drift(self):
        item = record()
        item["schema_version"] = 55
        item["reconciliation"]["source_hash"] = "a" * 64
        errors = validate_v56(item)
        self.assertTrue(any("schema_version must be 56" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v56(item)))


if __name__ == "__main__":
    unittest.main()
