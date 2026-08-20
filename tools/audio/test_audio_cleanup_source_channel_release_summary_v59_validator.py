"""Focused tests for v59 source/channel/release summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_channel_release_summary_v59_validator as validator  # noqa: E402


def summary() -> dict:
    source, channel, release = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "channel_digest": channel, "release_digest": release, "source_id": "source-v59", "channel_id": "channel-v59", "release_id": "release-v59", "release_version": "r59", "canonicalization": "json-sorted-v1", "evidence": evidence, "summary_pass": True}
    return {"schema": "audio_cleanup_source_channel_release_summary_v59", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-channel-release-v59", "evidence_bundle": "artifacts/audio/source-channel-release-v59.json", "canonicalization": "json-sorted-v1", "source_id": "source-v59", "channel_id": "channel-v59", "release_id": "release-v59", "release_version": "r59", "release_versions": ["r58", "r59"], "claim": "AUTOMATED_SOURCE_CHANNEL_RELEASE_ONLY", "boundary_note": "Source/channel/release summary does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "channel_digest": channel, "release_digest": release, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_channel_release_pass": True}


class AudioCleanupSourceChannelReleaseV59Tests(unittest.TestCase):
    def test_valid_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_channel_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["channel_id"] = "other"
        self.assertIn("records[1].channel_id must match summary", validator.validate_summary(value))

    def test_release_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["release_versions"] = ["r58"]
        self.assertIn("release_version must be in release_versions", validator.validate_summary(value))

    def test_summary_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_channel_release_pass"] = False
        value["records"][0]["summary_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_channel_release_pass must be true", errors)
        self.assertIn("records[0].summary_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
