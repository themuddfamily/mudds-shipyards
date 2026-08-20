import unittest

from tools.package.source_hash_channel_release_source_reconciliation_v57 import validate_v57


def record():
    commit = "c" * 40
    digest = "a" * 64
    source_id = "source-57"
    source_version = "src-57"
    package_version = "5.7.0"
    channel_id = "channel-57"
    release_id = "release-57"
    channel = "stable"
    return {
        "schema_version": 57,
        "build_label": "source-reconciliation-v57",
        "source_id": source_id,
        "channel_id": channel_id,
        "release_id": release_id,
        "release_channel": channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "source_id": source_id, "channel_id": channel_id, "release_id": release_id, "release_channel": channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashChannelReleaseSourceReconciliationV57Test(unittest.TestCase):
    def test_accepts_source_reconciliation(self):
        self.assertEqual(validate_v57(record()), [])

    def test_requires_source_and_release_identity_binding(self):
        item = record()
        item["reconciliation"]["source_id"] = "source-other"
        item["reconciliation"]["release_id"] = "release-other"
        errors = validate_v57(item)
        self.assertTrue(any("reconciliation.source_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.release_id must match" in error for error in errors))

    def test_rejects_schema_or_source_hash_drift(self):
        item = record()
        item["schema_version"] = 56
        item["reconciliation"]["source_hash"] = "b" * 64
        errors = validate_v57(item)
        self.assertTrue(any("schema_version must be 57" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v57(item)))


if __name__ == "__main__":
    unittest.main()
