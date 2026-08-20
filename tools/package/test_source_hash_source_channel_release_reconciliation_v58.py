import unittest

from tools.package.source_hash_source_channel_release_reconciliation_v58 import validate_v58


def record():
    commit = "d" * 40
    digest = "b" * 64
    source_id = "source-58"
    source_ref = "refs/tags/source-58"
    channel_id = "channel-58"
    release_id = "release-58"
    source_version = "src-58"
    package_version = "5.8.0"
    channel = "stable"
    return {
        "schema_version": 58,
        "build_label": "source-channel-release-v58",
        "source_id": source_id,
        "source_ref": source_ref,
        "channel_id": channel_id,
        "release_id": release_id,
        "release_channel": channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "reconciliation": {"status": "PASS", "evidence": "reconciliation", "source_id": source_id, "source_ref": source_ref, "channel_id": channel_id, "release_id": release_id, "release_channel": channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceChannelReleaseReconciliationV58Test(unittest.TestCase):
    def test_accepts_source_channel_release_reconciliation(self):
        self.assertEqual(validate_v58(record()), [])

    def test_requires_source_ref_and_release_binding(self):
        item = record()
        item["reconciliation"]["source_ref"] = "refs/heads/other"
        item["reconciliation"]["release_id"] = "release-other"
        errors = validate_v58(item)
        self.assertTrue(any("reconciliation.source_ref must match" in error for error in errors))
        self.assertTrue(any("reconciliation.release_id must match" in error for error in errors))

    def test_rejects_schema_or_hash_drift(self):
        item = record()
        item["schema_version"] = 57
        item["reconciliation"]["source_hash"] = "c" * 64
        errors = validate_v58(item)
        self.assertTrue(any("schema_version must be 58" in error for error in errors))
        self.assertTrue(any("reconciliation.source_hash must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v58(item)))


if __name__ == "__main__":
    unittest.main()
