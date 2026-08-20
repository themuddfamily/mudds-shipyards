"""Focused tests for v32 paired root/authority consensus summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_paired_root_authority_consensus_summary_v32_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c, d = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "summary_digest": a, "reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "root_id": "record-a", "authority_id": "authority-v32", "canonicalization": "json-sorted-v1", "evidence": evidence, "consensus_pass": True}
    return {"schema": "audio_cleanup_paired_root_authority_consensus_summary_v32", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-consensus-v32", "evidence_bundle": "artifacts/audio/consensus-v32.json", "canonicalization": "json-sorted-v1", "root_id": "record-a", "authority_id": "authority-v32", "claim": "AUTOMATED_PAIRED_ROOT_AUTHORITY_CONSENSUS_ONLY", "boundary_note": "Consensus does not establish native audibility.", "record_ids": ["record-a", "record-b"], "consensus_record_ids": ["record-a", "record-b"], "root_summary_digest": a, "root_reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "paired_consensus_pass": True}


class AudioCleanupPairedRootAuthorityConsensusV32Tests(unittest.TestCase):
    def test_valid_consensus_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_consensus_roster_is_bound(self):
        value = copy.deepcopy(summary())
        value["consensus_record_ids"] = ["record-a"]
        self.assertIn("consensus_record_ids must match record_ids", validator.validate_summary(value))

    def test_authority_pair_is_consistent(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_summary_digest"] = "e" * 64
        self.assertIn("records[1].authority_summary_digest must match summary", validator.validate_summary(value))

    def test_consensus_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["paired_consensus_pass"] = False
        value["records"][0]["consensus_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("paired_consensus_pass must be true", errors)
        self.assertIn("records[0].consensus_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
