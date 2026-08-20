import unittest

from tools.package.source_hash_channel_release_reconciliation_v55 import validate_v55


def record():
    commit = "a" * 40
    digest = "e" * 64
    source_version = "src-55"
    package_version = "5.5.0"
    channel_id = "channel-55"
    release_id = "release-55"
    release_channel = "stable"
    return {
        "schema_version": 55,
        "build_label": "channel-reconciliation-v55",
        "channel_id": channel_id,
        "release_id": release_id,
        "release_channel": release_channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "channel_id": channel_id, "release_id": release_id, "release_channel": release_channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashChannelReleaseReconciliationV55Test(unittest.TestCase):
    def test_accepts_channel_release_reconciliation(self):
        self.assertEqual(validate_v55(record()), [])

    def test_requires_channel_and_release_alignment(self):
        item = record()
        item["reconciliation"]["channel_id"] = "channel-other"
        item["reconciliation"]["release_id"] = "release-other"
        errors = validate_v55(item)
        self.assertTrue(any("reconciliation.channel_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.release_id must match" in error for error in errors))

    def test_rejects_schema_or_hash_drift(self):
        item = record()
        item["schema_version"] = 54
        item["reconciliation"]["source_hash"] = "f" * 64
        errors = validate_v55(item)
        self.assertTrue(any("schema_version must be 55" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "macOS"
        self.assertTrue(any("platform must be null" in error for error in validate_v55(item)))


if __name__ == "__main__":
    unittest.main()
