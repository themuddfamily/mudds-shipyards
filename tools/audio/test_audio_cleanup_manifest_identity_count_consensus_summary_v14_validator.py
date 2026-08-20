"""Focused tests for v14 cleanup manifest identity/count consensus."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_identity_count_consensus_summary_v14_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    records = [{"record_id": "record-1", "manifest_ids": ids, "manifest_count": 2, "evidence": "artifacts/audio/count-1.json", "count_pass": True}, {"record_id": "record-2", "manifest_ids": ids, "manifest_count": 2, "evidence": "artifacts/audio/count-2.json", "count_pass": True}]
    return {"schema": "audio_cleanup_manifest_identity_count_consensus_summary_v14", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-count-v14", "evidence_bundle": "artifacts/audio/count-v14.json", "claim": "AUTOMATED_MANIFEST_COUNT_ONLY", "boundary_note": "Manifest counts do not establish native audibility.", "manifest_ids": ids, "manifest_count": 2, "records": records, "identity_count_pass": True}


class AudioCleanupManifestCountV14Tests(unittest.TestCase):
    def test_valid_identity_count_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_summary_count_must_match_ids(self):
        value = copy.deepcopy(summary())
        value["manifest_count"] = 3
        errors = validator.validate_summary(value)
        self.assertIn("manifest_count must match manifest_ids length", errors)
        self.assertIn("records[0].manifest_count must match summary count", errors)

    def test_records_must_match_roster_and_count(self):
        value = copy.deepcopy(summary())
        value["records"][1]["manifest_ids"] = ["manifest-a"]
        value["records"][1]["manifest_count"] = 1
        errors = validator.validate_summary(value)
        self.assertIn("records[1].manifest_ids must match ordered summary roster", errors)
        self.assertIn("records[1].manifest_count must match summary count", errors)

    def test_order_and_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["manifest_ids"] = ["manifest-b", "manifest-a"]
        value["records"][0]["count_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("manifest_ids must be ordered, unique, and non-empty", errors)
        self.assertIn("records[0].count_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
