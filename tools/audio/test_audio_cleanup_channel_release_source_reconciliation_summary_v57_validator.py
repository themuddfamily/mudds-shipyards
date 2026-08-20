"""Focused tests for v57 channel/release source reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_channel_release_source_reconciliation_summary_v57_validator as validator  # noqa: E402


def summary() -> dict:
    channel, release, source, reconciliation = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "channel_digest": channel, "release_digest": release, "source_digest": source, "reconciliation_digest": reconciliation, "channel_id": "channel-v57", "release_id": "release-v57", "release_version": "r57", "source_id": "source-v57", "reconciliation_id": "reconciliation-v57", "canonicalization": "json-sorted-v1", "evidence": evidence, "source_reconciliation_pass": True}
    return {"schema": "audio_cleanup_channel_release_source_reconciliation_summary_v57", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-reconciliation-v57", "evidence_bundle": "artifacts/audio/source-reconciliation-v57.json", "canonicalization": "json-sorted-v1", "channel_id": "channel-v57", "release_id": "release-v57", "release_version": "r57", "release_versions": ["r56", "r57"], "source_id": "source-v57", "reconciliation_id": "reconciliation-v57", "claim": "AUTOMATED_CHANNEL_RELEASE_SOURCE_RECONCILIATION_ONLY", "boundary_note": "Source reconciliation does not establish native audibility.", "record_ids": ["record-a", "record-b"], "channel_digest": channel, "release_digest": release, "source_digest": source, "reconciliation_digest": reconciliation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "channel_source_reconciliation_pass": True}


class AudioCleanupChannelReleaseSourceReconciliationV57Tests(unittest.TestCase):
    def test_valid_source_reconciliation_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_source_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_id"] = "other"
        self.assertIn("records[1].source_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r56"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_source_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["channel_source_reconciliation_pass"] = False
        value["records"][0]["source_reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("channel_source_reconciliation_pass must be true", errors)
        self.assertIn("records[0].source_reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
