"""Focused tests for v55 channel/release reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_channel_release_reconciliation_summary_v55_validator as validator  # noqa: E402


def summary() -> dict:
    channel, release, reconciliation = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "channel_id": "channel-v55", "release_id": "release-v55", "reconciliation_id": "reconciliation-v55", "release_version": "r55", "canonicalization": "json-sorted-v1", "evidence": evidence, "channel_pass": True}
    return {"schema": "audio_cleanup_channel_release_reconciliation_summary_v55", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-channel-v55", "evidence_bundle": "artifacts/audio/channel-v55.json", "canonicalization": "json-sorted-v1", "channel_id": "channel-v55", "release_id": "release-v55", "reconciliation_id": "reconciliation-v55", "release_version": "r55", "release_versions": ["r54", "r55"], "claim": "AUTOMATED_CHANNEL_RELEASE_RECONCILIATION_ONLY", "boundary_note": "Channel reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "channel_reconciliation_pass": True}


class AudioCleanupChannelReleaseReconciliationV55Tests(unittest.TestCase):
    def test_valid_channel_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_channel_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["channel_id"] = "other"
        self.assertIn("records[1].channel_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r54"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_channel_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["channel_reconciliation_pass"] = False
        value["records"][0]["channel_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("channel_reconciliation_pass must be true", errors)
        self.assertIn("records[0].channel_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
