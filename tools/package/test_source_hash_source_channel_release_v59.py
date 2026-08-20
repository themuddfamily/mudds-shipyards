import unittest

from tools.package.source_hash_source_channel_release_v59 import validate_v59


def record():
    commit = "e" * 40
    digest = "c" * 64
    source_id = "source-59"
    source_ref = "refs/tags/source-59"
    channel_id = "channel-59"
    release_id = "release-59"
    source_version = "src-59"
    package_version = "5.9.0"
    channel = "stable"
    return {
        "schema_version": 59,
        "build_label": "source-channel-release-v59",
        "source_id": source_id,
        "source_ref": source_ref,
        "channel_id": channel_id,
        "release_id": release_id,
        "release_channel": channel,
        "source_commit": commit,
        "source_hash": digest,
        "source_version": source_version,
        "package_version": package_version,
        "source_attestation": {"status": "PASS", "evidence": "source attestation", "source_id": source_id, "source_ref": source_ref, "channel_id": channel_id, "release_id": release_id, "release_channel": channel, "source_commit": commit, "source_hash": digest, "source_version": source_version, "package_version": package_version, "attested": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSourceChannelReleaseV59Test(unittest.TestCase):
    def test_accepts_attested_source_channel_release(self):
        self.assertEqual(validate_v59(record()), [])

    def test_requires_attestation_source_and_release_binding(self):
        item = record()
        item["source_attestation"]["source_ref"] = "refs/heads/other"
        item["source_attestation"]["release_id"] = "release-other"
        errors = validate_v59(item)
        self.assertTrue(any("source_attestation.source_ref must match" in error for error in errors))
        self.assertTrue(any("source_attestation.release_id must match" in error for error in errors))

    def test_rejects_schema_or_unattested_record(self):
        item = record()
        item["schema_version"] = 58
        item["source_attestation"]["attested"] = False
        errors = validate_v59(item)
        self.assertTrue(any("schema_version must be 59" in error for error in errors))
        self.assertTrue(any("attested must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v59(item)))


if __name__ == "__main__":
    unittest.main()
