"""Focused tests for v16 cleanup manifest digest/count consensus."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_digest_count_consensus_summary_v16_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    digest = "c" * 64
    records = [{"record_id": "record-1", "manifest_ids": ids, "manifest_count": 2, "manifest_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/consensus-1.json", "consensus_pass": True}, {"record_id": "record-2", "manifest_ids": ids, "manifest_count": 2, "manifest_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/consensus-2.json", "consensus_pass": True}]
    return {"schema": "audio_cleanup_manifest_digest_count_consensus_summary_v16", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-consensus-v16", "evidence_bundle": "artifacts/audio/consensus-v16.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_MANIFEST_CONSENSUS_ONLY", "boundary_note": "Manifest consensus does not establish native audibility.", "manifest_ids": ids, "consensus_count": 2, "consensus_digest": digest, "records": records, "consensus_pass": True}


class AudioCleanupManifestConsensusV16Tests(unittest.TestCase):
    def test_valid_manifest_consensus(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_record_count_and_digest_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["manifest_count"] = 3
        value["records"][1]["manifest_digest"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records manifest_count values must agree", errors)
        self.assertIn("records manifest_digest values must agree", errors)

    def test_ordered_roster_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["manifest_ids"] = ["manifest-b", "manifest-a"]
        value["records"][1]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[0].manifest_ids must match ordered summary roster", errors)
        self.assertIn("records[1].canonicalization must match summary canonicalization", errors)

    def test_consensus_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["consensus_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("consensus_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
