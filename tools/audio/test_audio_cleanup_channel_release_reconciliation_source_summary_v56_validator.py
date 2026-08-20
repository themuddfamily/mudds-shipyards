"""Focused tests for v56 source-bound channel/release reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_channel_release_reconciliation_source_summary_v56_validator as validator  # noqa: E402


def summary() -> dict:
    channel, release, reconciliation = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "channel_id": "channel-v56", "channel_source": "source-v56", "release_id": "release-v56", "reconciliation_id": "reconciliation-v56", "release_version": "r56", "canonicalization": "json-sorted-v1", "evidence": evidence, "source_pass": True}
    return {"schema": "audio_cleanup_channel_release_reconciliation_source_summary_v56", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-channel-source-v56", "evidence_bundle": "artifacts/audio/channel-source-v56.json", "canonicalization": "json-sorted-v1", "channel_id": "channel-v56", "channel_source": "source-v56", "release_id": "release-v56", "reconciliation_id": "reconciliation-v56", "release_version": "r56", "release_versions": ["r55", "r56"], "claim": "AUTOMATED_CHANNEL_RELEASE_RECONCILIATION_SOURCE_ONLY", "boundary_note": "Channel source binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_channel_reconciliation_pass": True}


class AudioCleanupChannelReleaseReconciliationSourceV56Tests(unittest.TestCase):
    def test_valid_source_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_channel_source_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["channel_source"] = "other"
        self.assertIn("records[1].channel_source must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r55"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_source_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_channel_reconciliation_pass"] = False
        value["records"][0]["source_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_channel_reconciliation_pass must be true", errors)
        self.assertIn("records[0].source_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
