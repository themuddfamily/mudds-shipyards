"""Focused tests for v58 source/channel/release reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_channel_release_reconciliation_summary_v58_validator as validator  # noqa: E402


def summary() -> dict:
    source, channel, release, reconciliation = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "source_id": "source-v58", "channel_id": "channel-v58", "release_id": "release-v58", "release_version": "r58", "reconciliation_id": "reconciliation-v58", "canonicalization": "json-sorted-v1", "evidence": evidence, "source_pass": True}
    return {"schema": "audio_cleanup_source_channel_release_reconciliation_summary_v58", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-channel-v58", "evidence_bundle": "artifacts/audio/source-channel-v58.json", "canonicalization": "json-sorted-v1", "source_id": "source-v58", "channel_id": "channel-v58", "release_id": "release-v58", "release_version": "r58", "release_versions": ["r57", "r58"], "reconciliation_id": "reconciliation-v58", "claim": "AUTOMATED_SOURCE_CHANNEL_RELEASE_RECONCILIATION_ONLY", "boundary_note": "Source/channel reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "channel_digest": channel, "release_digest": release, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_channel_release_reconciliation_pass": True}


class AudioCleanupSourceChannelReleaseReconciliationV58Tests(unittest.TestCase):
    def test_valid_source_channel_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_source_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_id"] = "other"
        self.assertIn("records[1].source_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r57"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_source_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_channel_release_reconciliation_pass"] = False
        value["records"][0]["source_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_channel_release_reconciliation_pass must be true", errors)
        self.assertIn("records[0].source_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
